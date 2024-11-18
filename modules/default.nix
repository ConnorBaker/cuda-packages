{
  lib,
  ...
}:
let
  cuda-lib = import ../cuda-lib { inherit lib; };
  inherit (cuda-lib.utils) mkOptions;
  inherit (cuda-lib.types) majorMinorPatchVersion;
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
    cuda11MajorMinorPatchVersion = {
      description = ''
        Three-component version of the CUDA 11 versioned manifest to use.
        This option is should not be changed unless extending the CUDA package set through extraCudaModules and you need
        to use a different version of the CUDA 11 versioned manifest.
        NOTE: You must supply a versioned manifest of the same format as exists in this repo.
      '';
      default = "11.8.0";
      type = majorMinorPatchVersion;
    };
    cuda12MajorMinorPatchVersion = {
      description = ''
        Three-component version of the CUDA 12 versioned manifest to use.
        This option is should not be changed unless extending the CUDA package set through extraCudaModules and you need
        to use a different version of the CUDA 12 versioned manifest.
        NOTE: You must supply a versioned manifest of the same format as exists in this repo.
      '';
      default = "12.6.2";
      type = majorMinorPatchVersion;
    };
  };
}
