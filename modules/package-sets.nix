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
    attrValues
    dontRecurseIntoAttrs
    genAttrs
    mapAttrs
    recurseIntoAttrs
    ;
  inherit (lib.customisation) makeScope;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.lists)
    concatMap
    elem
    foldl'
    groupBy'
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
  # - Rename the platform type to redistPlatform to distinguish it from the Nix platform.

  redistArch = cuda-lib.utils.getRedistArch (
    config.data.jetsonTargets != [ ]
  ) stdenv.hostPlatform.system;
  mkCudaPackagesPackageSetName = flip pipe [
    (cuda-lib.utils.versionPolicyToVersionFunction config.redist.cuda.versionPolicy)
    (replaceStrings [ "." ] [ "_" ])
    (version: "cudaPackages_${version}")
  ];

  newestForComponent =
    versionPolicy: versionedManifests:
    let
      versionFunction = cuda-lib.utils.versionPolicyToVersionFunction versionPolicy;
      newestForEachVersionByPolicy = groupBy' (
        a: b: if versionAtLeast a b then a else b
      ) "0.0.0.0" versionFunction (attrNames versionedManifests);
      newestForEachVersion = genAttrs (attrValues newestForEachVersionByPolicy) (
        version: versionedManifests.${version}
      );
    in
    newestForEachVersion;

  index = mapAttrs (
    redistName: redistConfig: newestForComponent redistConfig.versionPolicy redistConfig.data
  ) config.redist;

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

        loosePackages = packagesFromDirectoryRecursive {
          inherit (final) callPackage;
          directory = ../packages;
        };

        redistributablePackages =
          let
            # trimmedFilteredIndex still has a tree-like structure. We will use it as a way to get the supported
            # redistributable architectures for each package.
            trimmedFilteredIndex = pipe index [
              (cuda-lib.utils.mkTrimmedIndex cudaMajorMinorPatchVersion)
              (cuda-lib.utils.mkFilteredIndex cudaMajorMinorPatchVersion)
            ];

            # Make a flattened index for the particular CUDA version.
            trimmedFilteredFlattenedIndex = cuda-lib.utils.mkFlattenedIndex trimmedFilteredIndex;

            # Fold function for the flattened index.
            flattenedIndexFoldFn =
              packages:
              flattenedIndexElem@{
                packageName,
                platform,
                redistName,
                releaseInfo,
                packageInfo,
                version,
                ...
              }:
              let
                supportedRedistArchs = pipe trimmedFilteredIndex [
                  # Get the packages entry for this package (mapping of platform to cudaVariant).
                  (index: index.${redistName}.${version}.${packageName}.packages)
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
                isSupportedPlatform = platform == "source" || elem redistArch supportedRedistArchs;

                # Fully versioned attribute name for the package.
                fullVersionedPackageName = cuda-lib.utils.mkVersionedPackageName {
                  inherit redistName packageName;
                  inherit (releaseInfo) version;
                  versionPolicy = "build";
                };

                # Included to allow us easy access to the most recent major version of the package.
                majorVersionedPackageName = cuda-lib.utils.mkVersionedPackageName {
                  inherit redistName packageName;
                  inherit (releaseInfo) version;
                  versionPolicy = "major";
                };

                # Package which is constructed from the current flattenedIndexElem.
                currentPackage = pipe flattenedIndexElem [
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
                    if isSupportedPlatform && redistArch == platform then
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

                    # If
                    # - only the current package is supported; or
                    # - the current package is newer than the existing package
                    # choose the current package.
                    if (!existingPackageIsSupported && currentPackageIsSupported) || existingPackageIsOlder then
                      currentPackage

                    # Else
                    # - only existing package is supported; and
                    # - the existing package is at least as new as the current package
                    # choose the existing package.
                    else
                      existingPackage

                  # Else there's no existing package with that name choose the current package.
                  else
                    currentPackage;
              in
              packages
              # NOTE: In the case we're processing a CUDA redistributable, the attribute name and the package name are
              #       the same, so we're effectively replacing the package twice.
              // {
                # Fully versioned package name case -- where we add a versioned package to the package set.
                ${fullVersionedPackageName} = packageForName fullVersionedPackageName;
              }
              // {
                # Major versioned package name case -- where we add a major versioned package to the package set.
                ${majorVersionedPackageName} = packageForName majorVersionedPackageName;
              }
              // {
                # Default package name case -- where we create the default version of a package for the package set.
                ${packageName} = packageForName packageName;
              };
          in
          # Fold our builder function over the flattened index.
          foldl' flattenedIndexFoldFn { } trimmedFilteredFlattenedIndex;
      in
      recurseIntoAttrs (
        coreAttrs // dataAttrs // utilityAttrs // loosePackages // redistributablePackages
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
      default = pipe index.cuda [
        attrNames
        (map packageSetBuilder)
        builtins.listToAttrs
      ];
    };
  };
}
