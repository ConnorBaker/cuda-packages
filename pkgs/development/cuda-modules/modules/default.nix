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
    ./fixups
    ./manifests
  ];

  options = mkOptions {
    cudaCapabilities = {
      description = ''
        Sets the default CUDA capabilities to target across all CUDA package sets.
        If empty, the default set of capabilities is determined per-package set.
      '';
      type = listOf cudaCapability;
    };
    cudaForwardCompat = {
      description = ''
        Sets the default value of the `cudaForwardCompat` configuration across all CUDA package sets.
      '';
      type = bool;
    };
    cudaForceRpath = {
      description = ''
        Sets the default value of the `cudaForceRpath` configuration across all CUDA package sets.
        When set, `cudaForceRpath` forces all CUDA packages (and consumers) to use RPATH instead of RUNPATH.

        NOTE: This can be used as temporary workaround for devices running Ubuntu JetPack 6 releases, where
        NVIDIA's CUDA driver libraries have neither RPATH nor RUNPATH set and tools like `nixGL` and `nixglhost`
        do not work or do not work with `cuda_compat`.
      '';
      type = bool;
    };
    hostNixSystem = {
      description = ''
        The Nix system of the host platform.
      '';
      type = nonEmptyStr;
    };
  };
}
