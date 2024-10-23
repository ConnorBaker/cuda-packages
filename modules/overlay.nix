{
  config,
  cuda-lib,
  lib,
  ...
}:
let
  inherit (builtins) toJSON;
  inherit (lib.attrsets)
    attrNames
    dontRecurseIntoAttrs
    foldlAttrs
    mapAttrs
    optionalAttrs
    recurseIntoAttrs
    ;
  inherit (lib.customisation) makeScope;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.lists)
    head
    length
    ;
  inherit (lib.options) mkOption;
  inherit (lib.strings)
    versionAtLeast
    versionOlder
    ;
  inherit (lib.trivial)
    const
    warn
    throwIf
    ;
  inherit (lib.types) raw;
  inherit (lib.versions) major majorMinor;

  packageSetBuilder =
    final:
    let
      hostRedistArch = cuda-lib.utils.getRedistArch (
        config.data.jetsonTargets != [ ]
      ) final.stdenv.hostPlatform.system;
    in
    cudaMajorMinorPatchVersion:
    let
      # Attribute set membership can depend on the CUDA version, so we declare these here and ensure they do not rely on
      # the fixed point.
      cudaMajorMinorVersion = majorMinor cudaMajorMinorPatchVersion;
      cudaMajorVersion = major cudaMajorMinorPatchVersion;

      isCuda11 = cudaMajorVersion == "11";
      isCuda12 = cudaMajorVersion == "12";
      isJetsonBuild = hostRedistArch == "linux-aarch64";

      # Packaging-specific utilities.
      desiredCudaVariant = cuda-lib.utils.mkCudaVariant cudaMajorMinorPatchVersion;
    in
    makeScope final.newScope (
      finalCudaPackages:
      recurseIntoAttrs {
        cuda-lib = dontRecurseIntoAttrs cuda-lib;

        cudaPackages = dontRecurseIntoAttrs finalCudaPackages // {
          __attrsFailEvaluation = true;
        };
        # NOTE: `cudaPackages_11_8.pkgs.cudaPackages.cudaVersion` is 11.8, not `cudaPackages.cudaVersion`.
        #       Effectively, people can use `cudaPackages_11_8.pkgs.callPackage` to have a world of Nixpkgs
        #       where the default CUDA version is 11.8.
        #       For example, OpenCV3 with CUDA 11.8: `cudaPackages_11_8.pkgs.opencv3`.
        # NOTE: Using `extend` allows us to maintain a reference to the final cudaPackages. Without this,
        #       if we use `finalCudaPackages.callPackage` and a package accepts `cudaPackages` as an argument, it's
        #       provided with `cudaPackages` from the top-level scope, which is not what we want. We want
        #       to provide the `cudaPackages` from the finalCudaPackages scope -- that is, the *current* scope.
        # NOTE: While the note attached to `extends` in `pkgs/top-level/stages.nix` states "DO NOT USE THIS
        #       IN NIXPKGS", this `pkgs` should never be evaluated by default, so it should have no impact.
        #       I (@connorbaker) am of the opinion that this is a valid use case for `extends`.
        pkgs = dontRecurseIntoAttrs (
          final.pkgs.extend (
            _: _: {
              __attrsFailEvaluation = true;
              inherit (finalCudaPackages) cudaPackages;
            }
          )
        );

        config = dontRecurseIntoAttrs config // {
          __attrsFailEvaluation = true;
        };

        # CUDA versions
        inherit cudaMajorMinorPatchVersion cudaMajorMinorVersion cudaMajorVersion;
        cudaVersion = warn "cudaPackages.cudaVersion is deprecated, use cudaPackages.cudaMajorMinorVersion instead" cudaMajorMinorVersion;

        # CUDA version comparison utilities
        cudaAtLeast = versionAtLeast cudaMajorMinorPatchVersion;
        cudaOlder = versionOlder cudaMajorMinorPatchVersion;

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
        // cuda-lib.utils.buildRedistPackages {
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
        directory = ../cudaPackages-common;
      }
      # cudaPackages_11-jetson
      // optionalAttrs (isCuda11 && isJetsonBuild) (packagesFromDirectoryRecursive {
        inherit (finalCudaPackages) callPackage;
        directory = ../cudaPackages_11-jetson;
      })
      # cudaPackages_12
      // optionalAttrs isCuda12 (packagesFromDirectoryRecursive {
        inherit (finalCudaPackages) callPackage;
        directory = ../cudaPackages_12;
      })
    );
in
{
  # Each attribute of packages is a CUDA version, and it maps to the set of packages for that CUDA version.
  options = mapAttrs (const mkOption) {
    overlay = {
      description = "Overlay to configure and add CUDA package sets";
      type = raw;
      default = final: prev: {
        config = prev.config // {
          allowUnfree = true;
          cudaSupport = true;
          cudaCapabilities = config.cuda.capabilities;
          cudaForwardCompat = config.cuda.forwardCompat;
          cudaHostCompiler = config.cuda.hostCompiler;
        };

        # Our package sets.
        cudaPackages_11 = packageSetBuilder final "11.8.0";
        cudaPackages_12 = packageSetBuilder final "12.6.2";
        cudaPackages = final.cudaPackages_12;

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
      };
    };
  };
}
