{
  cudaLib,
  lib,
  ...
}:
let
  inherit (cudaLib.types) cudaCapability;
  inherit (cudaLib.utils) mkOptions;
  inherit (lib.types) bool listOf nonEmptyStr;
in
{
  imports = [
    ./cuda-packages.nix
    ./data
    ./redists
  ];

  # Allow users extending CUDA package sets to specify the redist version to use.
  options = mkOptions {
    # Options
    cudaCapabilities = {
      description = ''
        Sets the default CUDA capabilities to target across all CUDA package sets.
        If empty, the default set of capabilities is determined per-package set.
      '';
      type = listOf cudaCapability;
      default = [ ];
    };
    cudaForwardCompat = {
      description = ''
        Sets the default value of the `cudaForwardCompat` configuration across all CUDA package sets.
      '';
      type = bool;
      default = false;
    };
    hostNixSystem = {
      description = ''
        The Nix system of the host platform.
      '';
      type = nonEmptyStr;
    };
  };
}
