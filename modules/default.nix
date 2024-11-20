{
  lib,
  ...
}:
let
  inherit (lib.cuda.utils) mkOptions;
  inherit (lib.cuda.types) cudaPackagesConfig;
  inherit (lib.modules) mkDefault;
in
{
  imports = [
    ./data
    ./redists
  ];

  # Allow users extending CUDA package sets to specify the redist version to use.
  options = mkOptions {
    cuda11 = {
      description = ''
        Configuration options for CUDA 11.
      '';
      type = cudaPackagesConfig;
    };
    cuda12 = {
      description = ''
        Configuration options for CUDA 12.
      '';
      type = cudaPackagesConfig;
    };
  };

  # Set defaults for our use.
  config = {
    cuda11 = {
      nvcc = {
        hostStdenv = mkDefault null;
        allowUnsupportedCompiler = mkDefault false;
      };
      majorMinorPatchVersion = mkDefault "11.8.0";
    };
    cuda12 = {
      nvcc = {
        hostStdenv = mkDefault null;
        allowUnsupportedCompiler = mkDefault false;
      };
      majorMinorPatchVersion = mkDefault "12.6.2";
    };
  };
}
