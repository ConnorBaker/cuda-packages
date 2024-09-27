{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config) cuda-lib;
  inherit (lib.attrsets) attrNames attrValues mapAttrs;
  inherit (lib.lists)
    concatMap
    filter
    intersectLists
    optionals
    ;
  inherit (lib.options) mkOption;
  inherit (lib.strings) versionOlder;
  inherit (lib.trivial) const flip pipe;
  inherit (lib.types) listOf nonEmptyListOf nonEmptyStr;

  mkOptions = mapAttrs (const mkOption);
in
{
  options.data = mkOptions {
    cudaRedistMajorMinorPatchVersions = {
      description = ''
        List of CUDA major.minor.patch versions provided by the redist packages

        Notable: CUDA versions from 11.4.4 are available as redist packages.
      '';
      type = nonEmptyListOf cuda-lib.types.majorMinorPatchVersion;
      default = attrNames config.redist.cuda.data;
    };
    cudatoolkitMajorMinorPatchVersions = {
      description = ''
        List of CUDA major.minor.patch versions provided by the runfile installer

        Notable: CUDA versions prior to 11.4.4 are not available as redist packages.
      '';
      type = nonEmptyListOf cuda-lib.types.majorMinorPatchVersion;
      default = pipe config.data.cudatoolkitRunfileReleases [
        attrValues
        (map ({ version, ... }: cuda-lib.utils.majorMinorPatch version))
        (filter (flip versionOlder "11.4.0"))
      ];
    };
    # These versions typically have at least three components.
    # NOTE: Because the python script which produces the index takes only the latest minor version for each major
    # release, there's no way for us to get collisions in creating the package sets (which are versioned by major and
    # minor releases).
    cudaMajorMinorPatchVersions = {
      description = ''
        List of CUDA major.minor.patch versions available across runfile installers and redist packages
      '';
      type = nonEmptyListOf cuda-lib.types.majorMinorPatchVersion;
      default =
        config.data.cudatoolkitMajorMinorPatchVersions ++ config.data.cudaRedistMajorMinorPatchVersions;
    };
    # This is used solely for utility functions getNixPlatform and getRedistArch which are needed before the flags
    # attribute set of values and functions is created in the package fixed-point.
    jetsonTargets = {
      description = "List of Jetson targets";
      type = listOf cuda-lib.types.cudaCapability;
      default =
        let
          allJetsonComputeCapabilities = concatMap (
            gpu: optionals gpu.isJetson [ gpu.computeCapability ]
          ) config.data.gpus;
        in
        intersectLists allJetsonComputeCapabilities (pkgs.config.cudaCapabilities or [ ]);
    };

    # TODO: Alphabetize
    platforms = {
      description = "List of platforms to use in creation of the platform type.";
      type = nonEmptyListOf nonEmptyStr;
      default = [
        "linux-aarch64"
        "linux-ppc64le"
        "linux-sbsa"
        "linux-x86_64"
        "source" # Source-agnostic platform
      ];
    };
    redistNames = {
      description = "List of redistributable names to use in creation of the redistName type.";
      type = nonEmptyListOf nonEmptyStr;
      default = [
        "cublasmp"
        "cuda"
        "cudnn"
        "cudss"
        "cuquantum"
        "cusolvermp"
        "cusparselt"
        "cutensor"
        # "nvidia-driver",  # NOTE: Some of the earlier manifests don't follow our scheme.
        "nvjpeg2000"
        "nvpl"
        "nvtiff"
        "tensorrt" # NOTE: not truly a redist; uses different naming convention
      ];
    };
    redistUrlPrefix = {
      description = "The prefix of the URL for redistributable files";
      default = "https://developer.download.nvidia.com/compute";
      type = nonEmptyStr;
    };
  };
}
