{
  lib,
  ...
}:
let
  inherit (lib.cuda.types) cudaPackagesConfig;
  inherit (lib.modules) mkDefault;
  inherit (lib.options) mkOption;
in
{
  imports = [
    ./data
    ./redists
  ];

  # Allow users extending CUDA package sets to specify the redist version to use.
  options.cuda12 = mkOption {
    description = ''
      Configuration options for CUDA 12.
    '';
    type = cudaPackagesConfig;
  };

  # Set defaults for our use.
  config.cuda12 = {
    nvcc = {
      hostStdenv = mkDefault null;
      allowUnsupportedCompiler = mkDefault false;
    };
    majorMinorPatchVersion = mkDefault "12.6.2";
    packagesDirectory = mkDefault ../cuda-packages/12.6.2;
  };
}
