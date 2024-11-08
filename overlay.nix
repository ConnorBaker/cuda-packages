final: prev:
let
  cuda-lib = import ./cuda-lib { inherit (final) lib; };

  inherit (final.lib.modules) evalModules;
  inherit
    (evalModules {
      modules = final.cudaModules;
    })
    config
    ;

  inherit (builtins) toJSON;
  inherit (cuda-lib.utils)
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
  inherit (final.lib.attrsets)
    attrNames
    dontRecurseIntoAttrs
    foldlAttrs
    optionalAttrs
    recurseIntoAttrs
    ;
  inherit (final.lib.customisation) makeScope;
  inherit (final.lib.filesystem) packagesFromDirectoryRecursive;
  inherit (final.lib.lists)
    foldl'
    head
    length
    ;
  inherit (final.lib.strings)
    versionAtLeast
    versionOlder
    ;
  inherit (final.lib.trivial)
    warn
    throwIf
    ;
  inherit (final.lib.versions) major majorMinor;

  hasJetsonTarget = getJetsonTargets config.data.gpus final.config.cudaCapabilities != [];

  hostRedistArch = getRedistArch hasJetsonTarget final.stdenv.hostPlatform.system;

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

      isCuda11 = cudaMajorVersion == "11";
      isCuda12 = cudaMajorVersion == "12";
      isJetsonBuild = hostRedistArch == "linux-aarch64";

      # Packaging-specific utilities.
      desiredCudaVariant = mkCudaVariant cudaMajorMinorPatchVersion;
    in
    makeScope final.newScope (
      finalCudaPackages:
      recurseIntoAttrs {
        cuda-lib = dontRecurseIntoAttrs cuda-lib;

        cudaPackages = dontRecurseIntoAttrs finalCudaPackages // {
          __attrsFailEvaluation = true;
        };

        pkgs = dontRecurseIntoAttrs final // {
          __attrsFailEvaluation = true;
        };

        config = dontRecurseIntoAttrs config // {
          __attrsFailEvaluation = true;
        };

        # CUDA versions
        inherit cudaMajorMinorPatchVersion cudaMajorMinorVersion cudaMajorVersion;
        cudaVersion = warn "cudaPackages.cudaVersion is deprecated, use cudaPackages.cudaMajorMinorVersion instead" cudaMajorMinorVersion;

        # CUDA version comparison utilities
        inherit
          cudaAtLeast
          cudaAtMost
          cudaBoundedExclusive
          cudaBoundedInclusive
          cudaNewer
          cudaOlder
          ;

        # Alilases
        cudaFlags = warn "cudaPackages.cudaFlags is deprecated, use cudaPackages.flags instead" finalCudaPackages.flags;
        cudnn_8_9 = throw "cudaPackages.cudnn_8_9 has been removed, use cudaPackages.cudnn instead";
      }
      # Redistributable packages
      // foldlAttrs (
        acc: redistName: redistConfig:
        let
          inherit (redistConfig) versionedManifests;
          manifestVersions =
            if redistName == "cuda" then [ cudaMajorMinorPatchVersion ] else attrNames versionedManifests;
          manifestVersion = head manifestVersions;
        in
        throwIf (
          length manifestVersions != 1
        ) "Expected exactly one version for ${redistName} manifests (found ${toJSON manifestVersions})" acc
        // buildRedistPackages {
          inherit
            desiredCudaVariant
            finalCudaPackages
            hostRedistArch
            redistName
            ;
          manifest = versionedManifests.${manifestVersion};
        }
      ) { } config.redists
      # cudaPackagesCommon
      // packagesFromDirectoryRecursive {
        inherit (finalCudaPackages) callPackage;
        directory = ./cudaPackages-common;
      }
      # cudaPackages_11-jetson
      // optionalAttrs (isCuda11 && isJetsonBuild) (packagesFromDirectoryRecursive {
        inherit (finalCudaPackages) callPackage;
        directory = ./cudaPackages_11-jetson;
      })
      # cudaPackages_12
      // optionalAttrs isCuda12 (packagesFromDirectoryRecursive {
        inherit (finalCudaPackages) callPackage;
        directory = ./cudaPackages_12;
      })
    );
in
{
  cudaModules = [ ./modules ];

  # # Our package sets, configured for the compute capabilities in config.
  cudaPackages_11 = packageSetBuilder "11.8.0";
  cudaPackages_12 = packageSetBuilder "12.6.2";
  cudaPackages = final.cudaPackages_12;

  # Nixpkgs package sets matrixed by real architecture (e.g., `sm_90a`).
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
    ) (dontRecurseIntoAttrs { }) config.data.gpus;

  # Package fixes
  openmpi = prev.openmpi.override (prevAttrs: {
    # The configure flag openmpi takes expects cuda_cudart to be joined.
    cudaPackages = prevAttrs.cudaPackages // {
      cuda_cudart = final.symlinkJoin {
        name = "cuda_cudart_joined";
        paths = map (
          output: prevAttrs.cudaPackages.cuda_cudart.${output}
        ) prevAttrs.cudaPackages.cuda_cudart.outputs;
      };
    };
  });
}
