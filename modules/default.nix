{
  lib,
  ...
}:
let
  cuda-lib = import ../cuda-lib { inherit lib; };
  inherit (cuda-lib.utils) mkOptions;
  inherit (cuda-lib.types) majorMinorPatchVersion;
  inherit (lib.modules) mkDefault;
  inherit (lib.types)
    bool
    nullOr
    package
    submodule
    ;

  nvccConfig = submodule {
    options = mkOptions {
      hostStdenv = {
        description = ''
          The host stdenv compiler to use when building CUDA code.
          This option is used to determine the version of the host compiler to use when building CUDA code.
          The default is selected by using config.data.nvcc-compatibilities.
        '';
        default = null;
        type = nullOr package;
      };
      allowUnsupportedCompiler = {
        description = ''
          Allow the use of an unsupported compiler when building CUDA code.
          This option is used to determine whether or not to allow the use of an unsupported compiler when building CUDA code.
          The default is false.
          https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/#allow-unsupported-compiler-allow-unsupported-compiler
        '';
        default = false;
        type = bool;
      };
    };
  };

  cudaPackagesConfig = submodule {
    options = mkOptions {
      nvcc = {
        description = ''
          Configuration options for nvcc.
        '';
        type = nvccConfig;
      };
      majorMinorPatchVersion = {
        description = ''
          Three-component version of the CUDA versioned manifest to use.
          This option is should not be changed unless extending the CUDA package set through extraCudaModules and you need
          to use a different version of the CUDA versioned manifest.
          NOTE: You must supply a versioned manifest of the same format as exists in this repo.
        '';
        type = majorMinorPatchVersion;
      };
    };
  };
in
{
  imports = [
    ./data
    ./redists
  ];

  config._module.args = {
    inherit cuda-lib;
  };

  options = mkOptions {
    # Allow users extending CUDA package sets to specify the redist version to use.
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
  config = {
    cuda11 = mkDefault {
      nvcc = mkDefault {
        hostStdenv = mkDefault null;
        allowUnsupportedCompiler = mkDefault false;
      };
      majorMinorPatchVersion = mkDefault "11.8.0";
    };
    cuda12 = mkDefault {
      nvcc = mkDefault {
        hostStdenv = mkDefault null;
        allowUnsupportedCompiler = mkDefault false;
      };
      majorMinorPatchVersion = mkDefault "12.6.2";
    };
  };
}
