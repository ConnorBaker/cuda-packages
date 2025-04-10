{
  config,
  cudaLib,
  lib,
  ...
}:
let
  inherit (cudaLib.types)
    attrs
    cudaPackagesConfig
    majorMinorPatchVersion
    ;
  inherit (lib.attrsets) genAttrs;
  inherit (lib.options) mkOption;
  inherit (lib.strings) versionOlder;
in
{
  # Use submodule merging to add a config block which is populated using the module fixpoint.
  # We do this here rather than below because these settings are sensible for all versions.
  imports = [ ./default-config.nix ];

  # Allow users extending CUDA package sets to specify the redist version to use.
  options.cudaPackages = mkOption {
    description = ''
      Versioned configuration options for each version of CUDA package set produced.
    '';
    type = attrs majorMinorPatchVersion cudaPackagesConfig;
    default = { };
  };

  config.cudaPackages = genAttrs config.data.cudaMajorMinorPatchVersions (
    cudaMajorMinorPatchVersion:
    let
      cudaPackagesConfig = config.cudaPackages.${cudaMajorMinorPatchVersion};
      inherit (cudaPackagesConfig) hasJetsonCudaCapability;
    in
    {
      packagesDirectories = [ ../../packages ];
      redists = {
        cublasmp = "0.4.0";
        cudnn = "9.8.0";
        cudss = "0.4.0";
        cuquantum = "24.11.0";
        cusolvermp = "0.6.0";
        cusparselt = if versionOlder cudaMajorMinorPatchVersion "12.8.0" then "0.6.3" else "0.7.0";
        cutensor = "2.1.0";
        nppplus = "0.9.0";
        nvcomp = "4.2.0.11";
        nvjpeg2000 = "0.8.1";
        nvpl = "25.1";
        nvtiff = "0.4.0";
        tensorrt = if hasJetsonCudaCapability then "10.7.0" else "10.8.0";
      };
    }
  );
}
