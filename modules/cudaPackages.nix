{
  config,
  lib,
  ...
}:
let
  inherit (lib.cuda.types)
    attrs
    cudaPackagesConfig
    majorMinorPatchVersion
    ;
  inherit (lib.cuda.utils)
    collectPackageConfigsForCudaVersion
    mkOptionsModule
    ;
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkMerge;
  inherit (lib.types) submodule;

  cudaConfig = config;
in
{
  imports = [
    # Use submodule merging to add a config block which is populated using the module fixpoint.
    (mkOptionsModule {
      cudaPackages.type = attrs majorMinorPatchVersion (
        submodule (
          # The value for CUDA version is the attribute name since this attribute set is indexed by CUDA version.
          { name, ... }:
          {
            config = {
              redists.cuda = name;
              packageConfigs = mkMerge (collectPackageConfigsForCudaVersion cudaConfig name);
            };
          }
        )
      );
    })
  ];

  # Allow users extending CUDA package sets to specify the redist version to use.
  options.cudaPackages = mkOption {
    description = ''
      Versioned configuration options for each version of CUDA package set produced.
    '';
    type = attrs majorMinorPatchVersion cudaPackagesConfig;
    default = { };
  };

  config.cudaPackages =
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
      # TODO: are there changes required for 12.2.2?
      "12.2.2" = common;
      "12.6.3" = common;
    };
}
