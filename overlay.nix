final: prev:
let
  lib = import ./lib { inherit (prev) lib; };
  cudaConfig =
    (evalModules {
      modules = [
        ./modules
        {
          cudaCapabilities = final.config.cudaCapabilities or [ ];
          cudaForwardCompat = final.config.cudaForwardCompat or true;
          hostNixSystem = final.stdenv.hostPlatform.system;
        }
      ] ++ final.cudaModules;
    }).config;

  inherit (builtins) throw;
  inherit (lib.attrsets)
    attrNames
    dontRecurseIntoAttrs
    mapAttrs'
    mergeAttrsList
    recurseIntoAttrs
    ;
  inherit (lib.cuda.utils)
    buildRedistPackages
    mkCudaVariant
    mkRealArchitecture
    versionAtMost
    versionBoundedExclusive
    versionBoundedInclusive
    versionNewer
    ;
  inherit (lib.customisation) makeScope;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.fixedPoints) composeManyExtensions extends;
  inherit (lib.lists) map;
  inherit (lib.modules) evalModules;
  inherit (lib.strings)
    replaceStrings
    versionAtLeast
    versionOlder
    ;
  inherit (lib.trivial) warn;
  inherit (lib.upstreamable.trivial) addNameToFetchFromGitLikeArgs;
  inherit (lib.versions) major majorMinor;

  inherit (cudaConfig) hostRedistArch;

  fetchFromGitHubAutoName =
    args: final.fetchFromGitHub (addNameToFetchFromGitLikeArgs final.fetchFromGitHub args);
  fetchFromGitLabAutoName =
    args: final.fetchFromGitLab (addNameToFetchFromGitLikeArgs final.fetchFromGitLab args);

  packageSetBuilder =
    cudaMajorMinorPatchVersion:
    let
      # Attribute set membership can depend on the CUDA version, so we declare these here and ensure they do not rely on
      # the fixed point.
      cudaMajorMinorVersion = majorMinor cudaMajorMinorPatchVersion;
      cudaMajorVersion = major cudaMajorMinorPatchVersion;

      cudaAtLeast = versionAtLeast cudaMajorMinorPatchVersion;
      cudaAtMost = versionAtMost cudaMajorMinorPatchVersion;
      cudaNewer = versionNewer cudaMajorMinorPatchVersion;
      cudaOlder = versionOlder cudaMajorMinorPatchVersion;
      cudaBoundedExclusive = min: max: versionBoundedExclusive min max cudaMajorMinorPatchVersion;
      cudaBoundedInclusive = min: max: versionBoundedInclusive min max cudaMajorMinorPatchVersion;

      # Packaging-specific utilities.
      desiredCudaVariant = mkCudaVariant cudaMajorMinorPatchVersion;

      cudaPackagesConfig = cudaConfig.cudaPackages.${cudaMajorMinorPatchVersion};

      cudaPackagesFun =
        finalCudaPackages:
        mergeAttrsList (
          [
            # Core attributes which largely don't depend on packages
            (recurseIntoAttrs {
              pkgs = dontRecurseIntoAttrs final // {
                __attrsFailEvaluation = true;
              };

              cudaPackages = dontRecurseIntoAttrs finalCudaPackages // {
                __attrsFailEvaluation = true;
              };

              # Introspection
              cudaPackagesConfig = dontRecurseIntoAttrs cudaPackagesConfig // {
                __attrsFailEvaluation = true;
              };

              # CUDA versions
              inherit cudaMajorMinorPatchVersion cudaMajorMinorVersion cudaMajorVersion;

              # CUDA version comparison utilities
              inherit
                cudaAtLeast
                cudaAtMost
                cudaBoundedExclusive
                cudaBoundedInclusive
                cudaNewer
                cudaOlder
                ;

              # Aliases
              backendStdenv = warn "cudaPackages.backendStdenv has been renamed, use cudaPackages.cudaStdenv instead" finalCudaPackages.cudaStdenv;
              cudaVersion = warn "cudaPackages.cudaVersion is deprecated, use cudaPackages.cudaMajorMinorVersion instead" cudaMajorMinorVersion;
              cudaFlags = warn "cudaPackages.cudaFlags is deprecated, use cudaPackages.flags instead" finalCudaPackages.flags;
              cudnn_8_9 = throw "cudaPackages.cudnn_8_9 has been removed, use cudaPackages.cudnn instead";

              # Utility function for automatically naming fetchFromGitHub derivations with `name`.
              fetchFromGitHub = fetchFromGitHubAutoName;
              fetchFromGitLab = fetchFromGitLabAutoName;
            })
          ]
          # Redistributable packages
          ++ map (
            redistName:
            let
              manifestVersion = cudaPackagesConfig.redists.${redistName};
              redistConfig = cudaConfig.redists.${redistName};
            in
            buildRedistPackages {
              inherit
                desiredCudaVariant
                finalCudaPackages
                hostRedistArch
                redistName
                ;
              callPackageOverriders = redistConfig.versionedOverrides.${manifestVersion} or { };
              manifest = redistConfig.versionedManifests.${manifestVersion};
            }
          ) (attrNames cudaPackagesConfig.redists)
          # CUDA version-specific packages
          ++ map (
            directory:
            packagesFromDirectoryRecursive {
              inherit (finalCudaPackages) callPackage;
              inherit directory;
            }
          ) cudaPackagesConfig.packagesDirectories
        );
    in
    makeScope final.newScope (
      # User additions are included through final.cudaPackagesExtensions
      extends (composeManyExtensions final.cudaPackagesExtensions) cudaPackagesFun
    );
in
# General configuration
{
  inherit lib;

  # For inspecting the results of the module system evaluation.
  cudaConfig = dontRecurseIntoAttrs cudaConfig // {
    __attrsFailEvaluation = true;
  };

  # For changing the manifests available.
  cudaModules = [ ];

  # For adding packages in an ad-hoc manner.
  cudaPackagesExtensions = [ ];
}
# Package sets
// {
  # We cannot add top-level attributes dependent on the fixed point, but we can add them within an attribute set!
  cudaPackagesVersions = mapAttrs' (cudaMajorMinorPatchVersion: _: {
    name = "cudaPackages_${replaceStrings [ "." ] [ "_" ] cudaMajorMinorPatchVersion}";
    value = packageSetBuilder cudaMajorMinorPatchVersion;
  }) cudaConfig.cudaPackages;

  # Aliases
  # NOTE: No way to automate this as presence or absence of attributes depends on the fixed point, which causes
  # infinite recursion.
  inherit (final.cudaPackagesVersions)
    cudaPackages_12_2_2
    cudaPackages_12_6_3
    ;

  cudaPackages_12_2 = final.cudaPackages_12_2_2;
  cudaPackages_12_6 = final.cudaPackages_12_6_3;

  cudaPackages_12 = final.cudaPackages_12_6;

  cudaPackages =
    final.cudaPackagesVersions."cudaPackages_${
      replaceStrings [ "." ] [ "_" ] cudaConfig.defaultCudaPackagesVersion
    }";
}
# Nixpkgs package sets matrixed by real architecture (e.g., `sm_90a`).
# TODO(@connorbaker): Yes, it is computationally expensive to call final.extend.
# No, I can't think of a different way to force re-evaluation of the fixed point.
// {
  pkgsCuda = mapAttrs' (cudaCapability: _: {
    name = mkRealArchitecture cudaCapability;
    value = dontRecurseIntoAttrs (
      final.extend (
        _: prev': {
          __attrsFailEvaluation = true;
          config = prev'.config // {
            cudaCapabilities = [ cudaCapability ];
          };
        }
      )
    );
  }) cudaConfig.data.gpus;
}
# Upstreamable packages
// packagesFromDirectoryRecursive {
  inherit (final) callPackage;
  directory = ./upstreamable-packages;
}
# Package fixes
// {
  openmpi = prev.openmpi.override {
    # The configure flag openmpi takes expects cuda_cudart to be joined.
    cudaPackages = final.cudaPackages // {
      cuda_cudart = final.symlinkJoin {
        name = "cuda_cudart_joined";
        paths = map (
          output: final.cudaPackages.cuda_cudart.${output}
        ) final.cudaPackages.cuda_cudart.outputs;
      };
    };
  };
}
