{
  lib,
  ...
}:
let
  inherit (lib.cuda.types) attrs cudaPackagesConfig majorMinorPatchVersion;
  inherit (lib.cuda.utils) mkOptions;
in
{
  imports = [
    ./data
    ./redists
  ];

  # Allow users extending CUDA package sets to specify the redist version to use.
  options = mkOptions {
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
    defaultCudaPackagesVersion = "12.6.3";
    cudaPackages = {
      # NOTE: CUDA 12.2.2 was the last release to support Xaviers running on JetPack 5 through cuda_compat.
      # https://docs.nvidia.com/cuda/cuda-for-tegra-appnote/index.html#deployment-considerations-for-cuda-upgrade-package
      "12.2.2" = {
        # TODO: are there changes required for 12.2.2?
        packagesDirectories = [ ../cuda-packages/common ];
        redists = {
          cublasmp = "0.3.0";
          cuda = "12.2.2";
          cudnn = "9.6.0";
          cudss = "0.3.0";
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
      "12.6.3" = {
        packagesDirectories = [ ../cuda-packages/common ];
        redists = {
          cublasmp = "0.3.0";
          cuda = "12.6.3";
          cudnn = "9.6.0";
          cudss = "0.3.0";
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
    };
  };
}
