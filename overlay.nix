final: prev:
let
  lib = import ./lib { inherit (prev) lib; };
  cudaConfig =
    (evalModules {
      modules = [ ./modules ] ++ final.cudaModules;
    }).config;

  inherit (builtins) throw;
  inherit (lib.cuda.utils)
    buildRedistPackages
    getJetsonTargets
    getRedistArch
    mkCudaVariant
    mkRealArchitecture
    versionAtMost
    versionBoundedExclusive
    versionBoundedInclusive
    versionNewer
    ;
  inherit (lib.attrsets)
    dontRecurseIntoAttrs
    foldlAttrs
    hasAttr
    mapAttrs'
    optionalAttrs
    recurseIntoAttrs
    ;
  inherit (lib.customisation) makeScope;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.fixedPoints) composeManyExtensions extends;
  inherit (lib.lists) foldl' optionals;
  inherit (lib.modules) evalModules;
  inherit (lib.strings)
    isString
    replaceStrings
    versionAtLeast
    versionOlder
    ;
  inherit (lib.trivial) warn;
  inherit (lib.upstreamable.trivial) addNameToFetchFromGitLikeArgs;
  inherit (lib.versions) major majorMinor;

  hasJetsonTarget =
    (getJetsonTargets cudaConfig.data.gpus (final.config.cudaCapabilities or [ ])) != [ ];

  hostRedistArch = getRedistArch hasJetsonTarget final.stdenv.hostPlatform.system;

  fetchFromGitHubAutoName = args: final.fetchFromGitHub (addNameToFetchFromGitLikeArgs args);
  fetchFromGitLabAutoName = args: final.fetchFromGitLab (addNameToFetchFromGitLikeArgs args);

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
        recurseIntoAttrs {
          cudaPackages = dontRecurseIntoAttrs finalCudaPackages // {
            __attrsFailEvaluation = true;
          };

          pkgs = dontRecurseIntoAttrs final // {
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

          # Utility function for automatically naming fetchFromGitHub derivations with `name`.
          fetchFromGitHub = fetchFromGitHubAutoName;
          fetchFromGitLab = fetchFromGitLabAutoName;

          # Ensure protobuf is fixed to a specific version which is broadly compatible.
          # TODO: Make conditional on not being cudaPackages_11-jetson, which supports older versions of software and
          # will require an older protobuf.
          # NOTE: This is currently blocked on onnxruntime:
          # https://github.com/microsoft/onnxruntime/issues/21308
          protobuf = final.protobuf_25;
        };

      extensions =
        [
          # Aliases
          (finalCudaPackages: _: {
            cudaVersion = warn "cudaPackages.cudaVersion is deprecated, use cudaPackages.cudaMajorMinorVersion instead" cudaMajorMinorVersion;
            cudaFlags = warn "cudaPackages.cudaFlags is deprecated, use cudaPackages.flags instead" finalCudaPackages.flags;
            cudnn_8_9 = throw "cudaPackages.cudnn_8_9 has been removed, use cudaPackages.cudnn instead";
          })
          # Common packages
          (
            finalCudaPackages: _:
            packagesFromDirectoryRecursive {
              inherit (finalCudaPackages) callPackage;
              directory = ./cuda-packages/common;
            }
          )
          # Redistributable packages
          # Fold over the redists specified in the cudaPackagesConfig
          (
            finalCudaPackages: _:
            foldlAttrs (
              acc: redistName: versionOrRedistArchToVersion:
              let
                maybeVersion =
                  # Check for same version used everywhere
                  if isString versionOrRedistArchToVersion then
                    versionOrRedistArchToVersion
                  # Check for hostArch
                  else if hasAttr hostRedistArch versionOrRedistArchToVersion then
                    versionOrRedistArchToVersion.${hostRedistArch}
                  # Default to being unavailable on the host
                  else
                    null;
              in
              acc
              // optionalAttrs (maybeVersion != null) (buildRedistPackages {
                inherit
                  desiredCudaVariant
                  finalCudaPackages
                  hostRedistArch
                  redistName
                  ;
                manifestVersion = maybeVersion;
                redistConfig = cudaConfig.redists.${redistName};
              })
            ) { } cudaPackagesConfig.redists
          )
        ]
        # CUDA version-specific packages
        ++ optionals (cudaPackagesConfig.packagesDirectory != null) [
          (
            finalCudaPackages: _:
            packagesFromDirectoryRecursive {
              inherit (finalCudaPackages) callPackage;
              directory = cudaPackagesConfig.packagesDirectory;
            }
          )
        ]
        # User additions
        ++ final.cudaPackagesExtensions;
    in
    makeScope final.newScope (extends (composeManyExtensions extensions) cudaPackagesFun);
in
# General configuration
{
  inherit lib;

  # For inspecting the results of the module system evaluation.
  inherit cudaConfig;

  # For changing the manifests available.
  cudaModules = [ ];

  # For adding packages in an ad-hoc manner.
  cudaPackagesExtensions = [ ];
}
# Package sets
// {
  # Alias
  cudaPackages =
    final.cudaPackagesVersions."cudaPackages_${
      replaceStrings [ "." ] [ "_" ] cudaConfig.defaultCudaPackagesVersion
    }";

  # We cannot add top-level attributes dependent on the fixed point, but we can add them within an attribute set!
  cudaPackagesVersions = mapAttrs' (cudaMajorMinorVersion: _: {
    name = "cudaPackages_${replaceStrings [ "." ] [ "_" ] cudaMajorMinorVersion}";
    value = packageSetBuilder cudaMajorMinorVersion;
  }) cudaConfig.cudaPackages;
}
# Nixpkgs package sets matrixed by real architecture (e.g., `sm_90a`).
// {
  # TODO(@connorbaker): Only keeps GPUs which are supported by the current CUDA version.
  pkgsCuda =
    let
      inherit (final.cudaPackages) cudaAtLeast cudaAtMost;
      isAarch64Linux = final.stdenv.hostPlatform.system == "aarch64-linux";
    in
    foldl' (
      acc:
      {
        computeCapability,
        isJetson,
        # TODO: Use versioned names (i.e., minCudaMajorMinorVersion)
        minCudaVersion,
        maxCudaVersion,
        ...
      }:
      acc
      //
        optionalAttrs
          (
            # Lower bound must be satisfied
            cudaAtLeast minCudaVersion
            # Upper bound must be empty or satisfied
            && (maxCudaVersion == null || cudaAtMost maxCudaVersion)
            # Jetson targets are only included when final.stdenv.hostPlatform.system is aarch64-linux
            && (isJetson -> isAarch64Linux)
          )
          {
            # TODO(@connorbaker): Yes, this is computationally expensive.
            # No, I can't think of a different way to force re-evaluation of the fixed point.
            ${mkRealArchitecture computeCapability} = final.extend (
              _: prev':
              dontRecurseIntoAttrs {
                __attrsFailEvaluation = true;
                config = prev'.config // {
                  cudaCapabilities = [ computeCapability ];
                };
              }
            );
          }
    ) (dontRecurseIntoAttrs { }) cudaConfig.data.gpus;
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
