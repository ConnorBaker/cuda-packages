{
  config,
  lib,
  ...
}:
let
  inherit (lib.cuda.types)
    attrs
    cudaCapability
    cudaPackagesConfig
    majorMinorPatchVersion
    redistArch
    ;
  inherit (lib.cuda.utils)
    getJetsonTargets
    getRedistArch
    mkOptions
    ;
  inherit (lib.modules) mkMerge;
  inherit (lib.types) bool listOf nonEmptyStr;
in
{
  imports = [
    ./data
    ./redists
  ];

  # Allow users extending CUDA package sets to specify the redist version to use.
  options = mkOptions {
    # Options
    cudaCapabilities = {
      description = ''
        The CUDA capabilities to target.
        If empty, uses the default set of capabilities determined per-package set.
      '';
      type = listOf cudaCapability;
    };
    cudaForwardCompat = {
      description = ''
        Whether to build with forward compatability enabled.
      '';
      type = bool;
    };
    hasJetsonTarget = {
      description = ''
        Whether the target platform is a Jetson device.
      '';
      type = bool;
    };
    hostRedistArch = {
      description = ''
        The architecture of the host platform for redistributable packages.
      '';
      type = redistArch;
    };
    hostNixSystem = {
      description = ''
        The Nix system of the host platform.
      '';
      type = nonEmptyStr;
    };

    # Package set creation
    defaultCudaPackagesVersion = {
      description = ''
        The CUDA package set to make default.
      '';
      type = majorMinorPatchVersion;
    };
    cudaPackages = {
      description = ''
        Versioned configuration options for each version of CUDA package set produced.
      '';
      type = attrs majorMinorPatchVersion cudaPackagesConfig;
      default = { };
    };
  };

  # Set defaults for our use.
  config = {
    hasJetsonTarget = (getJetsonTargets config.data.gpus config.cudaCapabilities) != [ ];

    hostRedistArch = getRedistArch config.hasJetsonTarget config.hostNixSystem;

    defaultCudaPackagesVersion = "12.6.3";
    cudaPackages =
      let
        common = {
          packagesDirectories = [ ../cuda-packages/common ];
          redists = {
            cublasmp = "0.3.1";
            cudnn = "9.6.0";
            cudss = "0.4.0";
            cuquantum = "24.11.0";
            cusolvermp = "0.5.1";
            cusparselt = "0.6.3";
            cutensor = "2.0.2.1";
            nppplus = "0.9.0";
            nvjpeg2000 = "0.8.1";
            nvpl = "24.7";
            nvtiff = "0.4.0";
            tensorrt = "10.7.0";
          };
        };
      in
      {
        # NOTE: CUDA 12.2.2 was the last release to support Xaviers running on JetPack 5 through cuda_compat.
        # https://docs.nvidia.com/cuda/cuda-for-tegra-appnote/index.html#deployment-considerations-for-cuda-upgrade-package
        "12.2.2" = mkMerge [
          common
          # TODO: are there changes required for 12.2.2?
          { redists.cuda = "12.2.2"; }
        ];
        "12.6.3" = mkMerge [
          common
          { redists.cuda = "12.6.3"; }
        ];
      };
  };
}
