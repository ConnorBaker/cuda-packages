{
  lib,
  ...
}:
let
  inherit (lib.cuda.types) attrs cudaPackagesConfig majorMinorPatchVersion;
  inherit (lib.cuda.utils) mkOptions;
  inherit (lib.modules) mkDefault;
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
    defaultCudaPackagesVersion = mkDefault "12.6.3";
    cudaPackages."12.6.3" = {
      packagesDirectory = mkDefault ../cuda-packages/12.6.3;
      redists = {
        cublasmp = "0.3.0";
        cuda = "12.6.3";
        cudnn = "9.5.1";
        cudss = "0.3.0";
        cuquantum = "24.11.0";
        cusolvermp = "0.5.1";
        cusparselt = "0.6.3";
        cutensor = "2.0.2.1";
        nppplus = "0.9.0";
        nvjpeg2000 = "0.8.0";
        nvpl = "24.7";
        nvtiff = "0.4.0";
        tensorrt = "10.6.0";
      };
    };
  };
}
