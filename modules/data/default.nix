{
  config,
  lib,
  ...
}:
let
  inherit (lib.attrsets) attrNames;
  inherit (lib.options) mkOption;
  inherit (lib.types) nonEmptyListOf;
in
{
  imports = [
    ./gpus.nix
    ./nvcc-compatibilities.nix
  ];
  options.data.cudaMajorMinorPatchVersions = mkOption {
    description = ''
      List of CUDA major.minor.patch versions available across runfile installers and redist packages
    '';
    type = nonEmptyListOf lib.cuda.types.majorMinorPatchVersion;
    default = attrNames config.redists.cuda.versionedManifests;
  };
}
