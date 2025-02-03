{
  config,
  lib,
  ...
}:
let
  inherit (lib.cuda.types)
    cudaCapability
    majorMinorPatchVersion
    redistArch
    ;
  inherit (lib.cuda.utils)
    getJetsonTargets
    getRedistArch
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
        Whether the target platform is a Jetson device.
      '';
      type = bool;
    };
    hostRedistArch = {
      description = ''
        The architecture of the host platform for redistributable packages.
      '';
      type = redistArch;
    };
    hostNixSystem = {
      description = ''
        The Nix system of the host platform.
      '';
      type = nonEmptyStr;
    };

    # Package set creation
    defaultCudaPackagesVersion = {
      description = ''
        The CUDA package set to make default.
      '';
      type = majorMinorPatchVersion;
    };
  };

  # Set defaults for our use.
  config = {
    hasJetsonTarget = (getJetsonTargets config.data.gpus config.cudaCapabilities) != [ ];
    hostRedistArch = getRedistArch config.hasJetsonTarget config.hostNixSystem;
  };
}
