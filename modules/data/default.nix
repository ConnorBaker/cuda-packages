{
  config,
  cuda-lib,
  lib,
  ...
}:
let
  inherit (cuda-lib.utils) mkOptions;
  inherit (lib.attrsets) attrNames;
  inherit (lib.lists) concatMap intersectLists optionals;
  inherit (lib.types) listOf nonEmptyListOf;
in
{
  imports = [
    ./gpus.nix
    ./nvcc-compatibilities.nix
  ];
  options.data = mkOptions {
    cudaMajorMinorPatchVersions = {
      description = ''
        List of CUDA major.minor.patch versions available across runfile installers and redist packages
      '';
      type = nonEmptyListOf cuda-lib.types.majorMinorPatchVersion;
      default = attrNames config.redists.cuda.versionedManifests;
    };
  };
}
