let
  inherit (builtins) throw warn;

  lib = import ../../lib;
  inherit (lib.attrsets)
    attrNames
    mapAttrs
    recursiveUpdate
    ;
  inherit (lib.customisation) callPackagesWith;
  inherit (lib.fixedPoints) composeManyExtensions extends;
  inherit (lib.lists) all foldl' map;
  inherit (lib.modules) evalModules;
  inherit (lib.strings) versionAtLeast versionOlder;
  inherit (lib.trivial)
    const
    flip
    mapNullable
    pipe
    ;
  inherit (lib.versions) major majorMinor;

  cudaLib = import ../development/cuda-modules/lib { inherit lib; };
  inherit (cudaLib.utils)
    addNameToFetchFromGitLikeArgs
    bimap
    dropDots
    mkCudaPackagesOverrideAttrsDefaultsFn
    mkCudaPackagesScope
    mkCudaPackagesVersionedName
    mkRealArchitecture
    packagesFromDirectoryRecursive'
    ;

  dontRecurseForDerivationsOrEvaluate =
    attrs:
    attrs
    // {
      # Don't recurse for derivations
      recurseForDerivations = false;
      # Don't attempt eval
      __attrsFailEvaluation = true;
    };

  mkCudaPackages =
    final: cudaPackagesConfig:
    let
      # NOTE: This value is considered an implementation detail and should not be exposed in the attribute set.
      inherit (cudaPackagesConfig) cudaMajorMinorPatchVersion;

      mkAlias = if final.config.allowAliases then warn else flip const throw;

      pkgs = dontRecurseForDerivationsOrEvaluate (
        let
          cudaPackagesMajorMinorPatchVersionName = mkCudaPackagesVersionedName cudaMajorMinorPatchVersion;
          cudaPackagesMajorMinorVersionName = mkCudaPackagesVersionedName (
            majorMinor cudaMajorMinorPatchVersion
          );
          cudaPackagesMajorVersionName = mkCudaPackagesVersionedName (major cudaMajorMinorPatchVersion);
          cudaPackagesUnversionedName = "cudaPackages";
        in
        if
          # Returns true if the three CUDA package set aliases match the provided CUDA package set version.
          all
            (
              packageSetAliasName:
              final.${packageSetAliasName}.cudaPackagesConfig.cudaMajorMinorPatchVersion
              == cudaMajorMinorPatchVersion
            )
            [
              cudaPackagesMajorMinorVersionName
              cudaPackagesMajorVersionName
              cudaPackagesUnversionedName
            ]
        then
          final
        else
          final.extend (
            final: _: {
              # cudaPackages_x_y = cudaPackages_x_y_z
              ${cudaPackagesMajorMinorVersionName} =
                final.cudaPackagesVersions.${cudaPackagesMajorMinorPatchVersionName};
              # cudaPackages_x = cudaPackages_x_y
              ${cudaPackagesMajorVersionName} = final.${cudaPackagesMajorMinorVersionName};
              # cudaPackages = cudaPackages_x
              ${cudaPackagesUnversionedName} = final.${cudaPackagesMajorVersionName};
            }
          )
      );

      cudaNamePrefix = "cuda${majorMinor cudaMajorMinorPatchVersion}";

      overrideAttrsDefaultsFn = mkCudaPackagesOverrideAttrsDefaultsFn {
        inherit (final) deduplicateRunpathEntriesHook;
        inherit cudaNamePrefix;
      };

      # Our package set is either built from a fixed-point function (AKA self-map), or from recursively merging attribute sets.
      # I choose recursively merging attribute sets because our scope is not flat, and with access to only the fixed point,
      # we cannot build nested scopes incrementally (like adding aliases) because later definitions would overwrite earlier ones.
      cudaPackagesFixedPoint =
        finalCudaPackages:
        foldl' recursiveUpdate
          (
            {
              inherit cudaNamePrefix;
              cudaPackages = dontRecurseForDerivationsOrEvaluate finalCudaPackages;
              cudaPackagesConfig = dontRecurseForDerivationsOrEvaluate cudaPackagesConfig;
              # NOTE: dontRecurseForDerivationsOrEvaluate is applied earlier to avoid the need to maintain two copies of
              # pkgs -- one with and one without it applied.
              inherit pkgs;

              # Core
              callPackages = callPackagesWith (pkgs // finalCudaPackages);
              cudaMajorMinorVersion = majorMinor cudaMajorMinorPatchVersion;

              # Utilities
              cudaAtLeast = versionAtLeast cudaMajorMinorPatchVersion;
              cudaOlder = versionOlder cudaMajorMinorPatchVersion;

              # Utility function for automatically naming fetchFromGitHub derivations with `name`.
              fetchFromGitHub =
                args: final.fetchFromGitHub (addNameToFetchFromGitLikeArgs final.fetchFromGitHub args);
              fetchFromGitLab =
                args: final.fetchFromGitLab (addNameToFetchFromGitLikeArgs final.fetchFromGitLab args);

              # Aliases
              flags = {
                cudaComputeCapabilityToName = mkAlias "cudaPackages.flags.cudaComputeCapabilityToName is deprecated, use cudaPackages.flags.cudaCapabilityToArchName instead" finalCudaPackages.flags.cudaCapabilityToArchName;
                dropDot = mkAlias "cudaPackages.flags.dropDot is deprecated, use cudaLibs.utils.dropDots instead" dropDots;
                isJetsonBuild = mkAlias "cudaPackages.flags.isJetsonBuild is deprecated, use cudaPackages.cudaPackagesConfig.hasJetsonCudaCapability instead" cudaPackagesConfig.hasJetsonCudaCapability;
              };
              backendStdenv = mkAlias "cudaPackages.backendStdenv has been removed, use stdenv instead" final.stdenv;
              cudaVersion = mkAlias "cudaPackages.cudaVersion is deprecated, use cudaPackages.cudaMajorMinorVersion instead" finalCudaPackages.cudaMajorMinorVersion;
              cudaMajorMinorPatchVersion = mkAlias "cudaPackages.cudaMajorMinorPatchVersion is an implementation detail, please use cudaPackages.cudaMajorMinorVersion instead" cudaPackagesConfig.cudaMajorMinorPatchVersion;
              cudaFlags = mkAlias "cudaPackages.cudaFlags is deprecated, use cudaPackages.flags instead" finalCudaPackages.flags;
              cudnn_8_9 = throw "cudaPackages.cudnn_8_9 has been removed, use cudaPackages.cudnn instead";
            }
            # Redistributable packages
            // mapAttrs (
              packageName:
              {
                callPackageOverrider,
                packageInfo,
                redistName,
                releaseInfo,
                srcArgs,
                supportedNixSystemAttrs,
                supportedRedistSystemAttrs,
              }:
              pipe
                {
                  inherit
                    packageInfo
                    packageName
                    redistName
                    releaseInfo
                    ;
                  src = mapNullable final.fetchzip srcArgs;
                  # NOTE: Don't need to worry about sorting the attribute names because Nix already does that.
                  supportedNixSystems = attrNames supportedNixSystemAttrs;
                  supportedRedistSystems = attrNames supportedRedistSystemAttrs;
                }
                [
                  # Build the package
                  finalCudaPackages.redist-builder
                  # Apply our defaults
                  (pkg: pkg.overrideAttrs overrideAttrsDefaultsFn)
                  # Apply optional fixups
                  (
                    pkg:
                    if callPackageOverrider == null then
                      pkg
                    else
                      pkg.overrideAttrs (finalCudaPackages.callPackage callPackageOverrider { })
                  )
                ]
            ) cudaPackagesConfig.packageConfigs
          )
          # CUDA version-specific packages
          (
            map (packagesFromDirectoryRecursive' finalCudaPackages.callPackage) cudaPackagesConfig.packagesDirectories
          );
    in
    mkCudaPackagesScope pkgs.newScope (
      # User additions are included through cudaPackagesExtensions
      extends (composeManyExtensions final.cudaPackagesExtensions) cudaPackagesFixedPoint
    );

in
final: _: {
  # Make sure to use `lib` from `prev` to avoid attribute names (in which attribute sets are strict) depending on the
  # fixed point, as this causes infinite recursion.
  cudaLib = dontRecurseForDerivationsOrEvaluate cudaLib;

  # For inspecting the results of the module system evaluation.
  cudaConfig =
    dontRecurseForDerivationsOrEvaluate
      (evalModules {
        modules = [
          ../development/cuda-modules/modules
          {
            cudaCapabilities = final.config.cudaCapabilities or [ ];
            cudaForwardCompat = final.config.cudaForwardCompat or true;
            hostNixSystem = final.stdenv.hostPlatform.system;
          }
        ] ++ final.cudaModules;
        specialArgs = {
          inherit (final) cudaLib;
        };
      }).config;

  # For changing the manifests available.
  cudaModules = [ ];

  # For adding packages in an ad-hoc manner.
  cudaPackagesExtensions = [ ];

  # Versioned package sets
  cudaPackagesVersions = dontRecurseForDerivationsOrEvaluate (
    bimap mkCudaPackagesVersionedName (mkCudaPackages final) final.cudaConfig.cudaPackages
  );

  # Package set aliases with a major and minor component are drawn directly from final.cudaPackagesVersions.
  # The patch-versioned package sets are not available at the top level because they may be removed without
  # notice.
  cudaPackages_12_2 = final.cudaPackagesVersions.cudaPackages_12_2_2;
  cudaPackages_12_6 = final.cudaPackagesVersions.cudaPackages_12_6_3;
  cudaPackages_12_8 = final.cudaPackagesVersions.cudaPackages_12_8_0;
  # Package set aliases with a major component refer to an alias with a major and minor component in final.
  # TODO: Deferring upgrade to CUDA 12.8 until separate compilation works.
  cudaPackages_12 = final.cudaPackages_12_6;
  # Unversioned package set alias refers to an alias with a major component in final.
  cudaPackages = final.cudaPackages_12;

  # Nixpkgs package sets matrixed by real architecture (e.g., `sm_90a`).
  # TODO(@connorbaker): Yes, it is computationally expensive to call nixpkgsFun.
  # No, I can't think of a different way to force re-evaluation of the fixed point -- the problem being that
  # pkgs.config is not part of the fixed point.
  pkgsCuda =
    let
      mkPkgs =
        cudaCapabilityInfo:
        final.extend (
          _: prev:
          dontRecurseForDerivationsOrEvaluate {
            config = prev.config // {
              cudaCapabilities = [ cudaCapabilityInfo.cudaCapability ];
            };
          }
        );
    in
    dontRecurseForDerivationsOrEvaluate (
      bimap mkRealArchitecture mkPkgs final.cudaConfig.data.cudaCapabilityToInfo
    );
}
