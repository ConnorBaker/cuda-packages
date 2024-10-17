{
  config,
  cuda-lib,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.attrsets)
    attrNames
    dontRecurseIntoAttrs
    mapAttrs
    optionalAttrs
    recurseIntoAttrs
    ;
  inherit (lib.customisation) makeScope;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.lists)
    concatMap
    elem
    foldl'
    map
    unique
    ;
  inherit (lib.options) mkOption;
  inherit (lib.strings) replaceStrings versionAtLeast versionOlder;
  inherit (lib.trivial) const flip pipe;
  inherit (lib.types) lazyAttrsOf raw;
  inherit (lib.versions) major majorMinor;
  inherit (pkgs) newScope stdenv;

  # TODO:
  # - Version constraint handling (like for cutensor)
  # - Overrides for cutensor, etc.

  hostRedistArch = cuda-lib.utils.getRedistArch (
    config.data.jetsonTargets != [ ]
  ) stdenv.hostPlatform.system;

  mkCudaPackagesPackageSetName = flip pipe [
    (cuda-lib.utils.versionPolicyToVersionFunction config.redists.cuda.versionPolicy)
    (replaceStrings [ "." ] [ "_" ])
    (version: "cudaPackages_${version}")
  ];

  packageSetBuilder = cudaMajorMinorPatchVersion: {
    name = mkCudaPackagesPackageSetName cudaMajorMinorPatchVersion;
    value = makeScope newScope (
      final:
      let
        coreAttrs = {
          cuda-lib = dontRecurseIntoAttrs cuda-lib;

          cudaPackages = dontRecurseIntoAttrs final // {
            __attrsFailEvaluation = true;
          };
          # NOTE: `cudaPackages_11_8.pkgs.cudaPackages.cudaVersion` is 11.8, not `cudaPackages.cudaVersion`.
          #       Effectively, people can use `cudaPackages_11_8.pkgs.callPackage` to have a world of Nixpkgs
          #       where the default CUDA version is 11.8.
          #       For example, OpenCV3 with CUDA 11.8: `cudaPackages_11_8.pkgs.opencv3`.
          # NOTE: Using `extend` allows us to maintain a reference to the final cudaPackages. Without this,
          #       if we use `final.callPackage` and a package accepts `cudaPackages` as an argument, it's
          #       provided with `cudaPackages` from the top-level scope, which is not what we want. We want
          #       to provide the `cudaPackages` from the final scope -- that is, the *current* scope.
          # NOTE: While the note attached to `extends` in `pkgs/top-level/stages.nix` states "DO NOT USE THIS
          #       IN NIXPKGS", this `pkgs` should never be evaluated by default, so it should have no impact.
          #       I (@connorbaker) am of the opinion that this is a valid use case for `extends`.
          pkgs = dontRecurseIntoAttrs (
            pkgs.extend (
              _: _: {
                __attrsFailEvaluation = true;
                inherit (final) cudaPackages;
              }
            )
          );
        };

        dataAttrs = {
          config = dontRecurseIntoAttrs config // {
            __attrsFailEvaluation = true;
          };
          # CUDA versions
          inherit cudaMajorMinorPatchVersion;
          cudaMajorMinorVersion = majorMinor final.cudaMajorMinorPatchVersion;
          cudaMajorVersion = major final.cudaMajorMinorPatchVersion;
          cudaVersion = final.cudaMajorMinorVersion;
        };

        utilityAttrs = {
          # CUDA version comparison utilities
          cudaAtLeast = versionAtLeast final.cudaVersion;
          cudaOlder = versionOlder final.cudaVersion;
        };

        cudaPackages_11-jetson = packagesFromDirectoryRecursive {
          inherit (final) callPackage;
          directory = ../cudaPackages_11-jetson;
        };

        cudaPackages_12 = packagesFromDirectoryRecursive {
          inherit (final) callPackage;
          directory = ../cudaPackages_12;
        };

        cudaPackagesCommon = packagesFromDirectoryRecursive {
          inherit (final) callPackage;
          directory = ../cudaPackages-common;
        };

        addRedistributablePackages =
          initialPackages:
          let
            # trimmedFilteredRedists still has a tree-like structure. We will use it as a way to get the supported
            # redistributable architectures for each package.
            trimmedFilteredRedists = pipe config.redists [
              (cuda-lib.utils.mkTrimmedRedists cudaMajorMinorPatchVersion)
              (cuda-lib.utils.mkFilteredRedists cudaMajorMinorPatchVersion)
            ];

            # Make a flattened redists value for the particular CUDA version.
            trimmedFilteredFlattenedRedists = cuda-lib.utils.mkFlattenedRedists trimmedFilteredRedists;

            # Fold function for the flattened redists value.
            flattenedRedistsFoldFn =
              packages:
              flattenedRedistsElem@{
                packageName,
                redistArch,
                redistName,
                releaseInfo,
                packageInfo,
                version,
                ...
              }:
              let
                supportedRedistArchs = pipe trimmedFilteredRedists [
                  # Get the packages entry for this package (mapping of redistArch to cudaVariant).
                  (redists: redists.${redistName}.versionedManifests.${version}.${packageName}.packages)
                  # Get the list of redistributable architectures for this package.
                  attrNames
                ];
                supportedNixPlatforms = pipe supportedRedistArchs [
                  # Get the Nix platforms for each redistributable architecture.
                  (concatMap cuda-lib.utils.getNixPlatforms)
                  # Take only the unique platforms.
                  unique
                ];

                # NOTE: We must check for compatibility with the redistributable architecture, not the Nix platform,
                #       because the redistributable architecture is able to disambiguate between aarch64-linux with and
                #       without Jetson support (`linux-aarch64` and `linux-sbsa`, respectively).
                isSupportedPlatform = redistArch == "source" || elem hostRedistArch supportedRedistArchs;

                inherit (config.redists.${redistName}) versionPolicy;

                # Package which is constructed from the current flattenedRedistsElem.
                currentPackage = pipe flattenedRedistsElem [
                  # Use the package builder
                  (cuda-lib.utils.buildRedistPackage final)
                  # Update meta with the list of supported platforms
                  (
                    pkg:
                    pkg.overrideAttrs (prevAttrs: {
                      meta = prevAttrs.meta // {
                        platforms = supportedNixPlatforms;
                      };
                    })
                  )
                  # Set `src` to null and `outputs` to "out" if the package is not supported on the current platform.
                  # NOTE: This allows us to add packages to the package set when they wouldn't otherwise be visible
                  #       on the platform.
                  #       We set the source to null to avoid having a source for a different platform as the source
                  #       for an unsupported platform. The same reasoning extends to resetting outputs --
                  #       different platforms have different outputs, and we don't want to have an arbitrary set
                  #       of outputs corresponding to a different platform listed as the outputs for the
                  #       unsupported platform.
                  (
                    pkg:
                    if isSupportedPlatform && hostRedistArch == redistArch then
                      pkg
                    else
                      pkg.overrideAttrs {
                        src = null;
                        outputs = [ "out" ];
                      }
                  )
                ];

                # Choose the package to use -- one existing in the package set, or the one we're processing.
                # This function is responsible for ensuring a consistent attribute set across platforms.
                packageForName =
                  name:
                  # If there's an existing package with that name
                  if packages ? ${name} then
                    let
                      currentPackageIsSupported = currentPackage.src != null;

                      existingPackage = packages.${name};
                      existingPackageIsSupported = existingPackage.src != null;
                      existingPackageIsOlder = versionOlder existingPackage.version currentPackage.version;
                    in

                    # If the current package is supported and either the existing package is older or not supported,
                    # choose the current package.
                    if currentPackageIsSupported && (existingPackageIsOlder || !existingPackageIsSupported) then
                      currentPackage

                    # Otherwise, choose the existing package.
                    else
                      existingPackage

                  # Else there's no existing package with that name choose the current package.
                  else
                    currentPackage;
              in
              packages
              // {
                # Default package name case -- where we create the default version of a package for the package set.
                ${packageName} = packageForName packageName;
              };
          in
          # Fold our builder function over the flattened redists.
          foldl' flattenedRedistsFoldFn initialPackages trimmedFilteredFlattenedRedists;
      in
      recurseIntoAttrs (
        (addRedistributablePackages (
          coreAttrs
          // dataAttrs
          // utilityAttrs
          // cudaPackagesCommon
          // (optionalAttrs (major cudaMajorMinorPatchVersion == "12") cudaPackages_12)
        ))
        // optionalAttrs (
          ((major cudaMajorMinorPatchVersion == "11") && hostRedistArch == "linux-aarch64")
        ) cudaPackages_11-jetson
      )
    );
  };
in
{
  # Each attribute of packages is a CUDA version, and it maps to the set of packages for that CUDA version.
  options = mapAttrs (const mkOption) {
    packageSets = {
      description = "Package sets for each version of CUDA.";
      # NOTE: We must use lazyAttrsOf, else the package set is evaluated immediately for every CUDA version, instead
      # of lazily.
      type = lazyAttrsOf raw;
      default =
        let
          versionedPackageSets = pipe config.redists.cuda.versionedManifests [
            (cuda-lib.utils.newestVersionedManifestsByVersionPolicy config.redists.cuda.versionPolicy)
            attrNames
            (map packageSetBuilder)
            builtins.listToAttrs
          ];
        in
        versionedPackageSets // { cudaPackages = versionedPackageSets.cudaPackages_12; };
    };
  };
}
