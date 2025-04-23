let
  inherit (builtins) throw warn;
  dontRecurseForDerivationsOrEvaluate =
    attrs:
    attrs
    // {
      # Don't recurse for derivations
      recurseForDerivations = false;
      # Don't attempt eval
      __attrsFailEvaluation = true;
    };
in
{
  config,
  cudaLib,
  emptyDirectory,
  cudaPackagesExtensions,
  lib,
  pkgs,
  # Manually provided arguments
  fixups,
  manifests,
}:
let
  inherit (lib.attrsets)
    attrNames
    hasAttr
    mapAttrs
    mergeAttrsList
    ;
  inherit (lib.customisation) callPackagesWith;
  inherit (lib.fixedPoints) composeManyExtensions extends;
  inherit (lib.lists) concatMap;
  inherit (lib.strings) versionAtLeast versionOlder;
  inherit (lib.trivial) const flip importJSON;
  inherit (lib.versions) major majorMinor;
  inherit (cudaLib.utils)
    dropDots
    formatCapabilities
    mkCudaPackagesVersionedName
    packagesFromDirectoryRecursive'
    ;

  # NOTE: This value is considered an implementation detail and should not be exposed in the attribute set.
  cudaMajorMinorPatchVersion = manifests.cuda.release_label;

  cudaPackagesMajorMinorVersionName = mkCudaPackagesVersionedName (
    majorMinor cudaMajorMinorPatchVersion
  );

  mkAlias = if config.allowAliases then warn else flip const throw;

  pkgs' = dontRecurseForDerivationsOrEvaluate (
    let
      cudaPackagesMajorVersionName = mkCudaPackagesVersionedName (major cudaMajorMinorPatchVersion);
      cudaPackagesUnversionedName = "cudaPackages";
    in
    pkgs.extend (
      final: _: {
        # cudaPackages_x = cudaPackages_x_y
        ${cudaPackagesMajorVersionName} = final.${cudaPackagesMajorMinorVersionName};
        # cudaPackages = cudaPackages_x
        ${cudaPackagesUnversionedName} = final.${cudaPackagesMajorVersionName};
      }
    )
  );

  cudaNamePrefix = "cuda${majorMinor cudaMajorMinorPatchVersion}";

  cudaPackagesFixedPoint =
    finalCudaPackages:
    let
      redistBuilderArgs = mergeAttrsList (
        concatMap (
          redistName:
          concatMap (
            packageName:
            # Only add the configuration for the package from the manifest if we have a fixup for it.
            # NOTE: Since manifests have non-package keys, this also gets rid of entries like "release_label".
            lib.optionals (hasAttr packageName fixups.${redistName}) [
              {
                ${packageName} = {
                  inherit packageName redistName;
                  release = manifests.${redistName}.${packageName};
                  fixupFn = fixups.${redistName}.${packageName};
                };
              }
            ]
          ) (attrNames manifests.${redistName})
        ) (attrNames manifests)
      );
    in
    {
      inherit cudaNamePrefix;

      # NOTE: dontRecurseForDerivationsOrEvaluate is applied earlier to avoid the need to maintain two copies of
      # pkgs -- one with and one without it applied.
      pkgs = pkgs';

      # Self-reference
      cudaPackages = dontRecurseForDerivationsOrEvaluate finalCudaPackages;

      # Core
      callPackages = callPackagesWith (pkgs' // finalCudaPackages);

      # These must be modified through callPackage, not by overriding the scope, since we cannot
      # depend on them recursively as they are used to add top-level attributes.
      inherit fixups manifests;

      # Versions
      cudaMajorMinorVersion = majorMinor cudaMajorMinorPatchVersion;
      cudaMajorVersion = major cudaMajorMinorPatchVersion;

      # Utilities
      cudaAtLeast = versionAtLeast cudaMajorMinorPatchVersion;
      cudaOlder = versionOlder cudaMajorMinorPatchVersion;

      # Alternative versions of select packages.
      # This should be minimized as much as possible.
      cudnn_8_9 = finalCudaPackages.redist-builder {
        packageName = "cudnn";
        redistName = "cudnn";
        release =
          let
            manifest =
              if finalCudaPackages.cudaStdenv.hasJetsonCudaCapability then
                ./manifests/cudnn/redistrib_8.9.5.json
              else
                ./manifests/cudnn/redistrib_8.9.7.json;
          in
          (importJSON manifest).cudnn;
        fixupFn = fixups.cudnn.cudnn;
      };

      # Aliases
      # NOTE: flags is defined here to prevent a collision with an attribute of the same name from cuda-modules/packages.
      flags =
        dontRecurseForDerivationsOrEvaluate (formatCapabilities {
          inherit (finalCudaPackages.cudaStdenv) cudaCapabilities cudaForwardCompat;
          inherit (cudaLib.data) cudaCapabilityToInfo;
        })
        // {
          cudaComputeCapabilityToName = throw "cudaPackages.flags.cudaComputeCapabilityToName has been removed";
          dropDot = mkAlias "cudaPackages.flags.dropDot is deprecated, use cudaLibs.utils.dropDots instead" dropDots;
          isJetsonBuild = mkAlias "cudaPackages.flags.isJetsonBuild is deprecated, use cudaPackages.cudaStdenv.hasJetsonCudaCapability instead" finalCudaPackages.cudaStdenv.hasJetsonCudaCapability;
        };

      ## Aliases for deprecated attributes
      autoAddCudaCompatRunpath = mkAlias "cudaPackages.autoAddCudaCompatRunpath is deprecated and no longer necessary" emptyDirectory;
      backendStdenv = mkAlias "cudaPackages.backendStdenv has been removed, use cudaPackages.cudaStdenv instead" finalCudaPackages.cudaStdenv;
      cudaFlags = mkAlias "cudaPackages.cudaFlags is deprecated, use cudaPackages.flags instead" finalCudaPackages.flags;
      cudaMajorMinorPatchVersion = mkAlias "cudaPackages.cudaMajorMinorPatchVersion is an implementation detail, please use cudaPackages.cudaMajorMinorVersion instead" cudaMajorMinorPatchVersion;
      cudaVersion = mkAlias "cudaPackages.cudaVersion is deprecated, use cudaPackages.cudaMajorMinorVersion instead" finalCudaPackages.cudaMajorMinorVersion;
      markForCudatoolkitRootHook = mkAlias "cudaPackages.markForCudatoolkitRootHook has moved, use cudaPackages.markForCudaToolkitRootHook instead" finalCudaPackages.markForCudaToolkitRootHook;
    }
    # Redistributable packages
    // mapAttrs (const finalCudaPackages.redist-builder) redistBuilderArgs
    # CUDA version-specific packages
    # NOTE: No need for recurseIntoAttrs on the package set as packagesFromDirectoryRecursive' applies it automatically,
    # and so the union of the attribute sets will have it as well.
    // packagesFromDirectoryRecursive' finalCudaPackages.callPackage ./packages;

in
pkgs'.makeScopeWithSplicing' {
  otherSplices = pkgs'.generateSplicesForMkScope [ cudaPackagesMajorMinorVersionName ];
  # User additions are included through cudaPackagesExtensions
  f = extends (composeManyExtensions cudaPackagesExtensions) cudaPackagesFixedPoint;
}
