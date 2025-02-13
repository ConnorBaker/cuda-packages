{
  config,
  cudaLib,
  lib,
  ...
}:
let
  inherit (cudaLib.types)
    cudaCapability
    redistSystem
    ;
  inherit (cudaLib.utils)
    getJetsonTargets
    getRedistSystem
    mkOptions
    ;
  inherit (lib.types) bool listOf nonEmptyStr;
in
{
  imports = [
    ./cudaPackages.nix
    ./data
    ./redists
  ];

  # Allow users extending CUDA package sets to specify the redist version to use.
  options = mkOptions {
    # Options
    cudaCapabilities = {
      description = ''
        The CUDA capabilities to target.
        If empty, uses the default set of capabilities determined per-package set.
      '';
      type = listOf cudaCapability;
    };
    cudaForwardCompat = {
      description = ''
        Whether to build with forward compatability enabled.
      '';
      type = bool;
    };
    hasJetsonTarget = {
      description = ''
        Whether the target capabilities include a Jetson system.
      '';
      type = bool;
    };
    hostRedistSystem = {
      description = ''
        The redistributable system of the host platform, to be used for redistributable packages.
      '';
      type = redistSystem;
    };
    hostNixSystem = {
      description = ''
        The Nix system of the host platform.
      '';
      type = nonEmptyStr;
    };
  };

  # Set defaults for our use.
  config = {
    hasJetsonTarget = (getJetsonTargets config.data.gpus config.cudaCapabilities) != [ ];
    hostRedistSystem = getRedistSystem config.hasJetsonTarget config.hostNixSystem;
  };
}
