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
    # This is used solely for utility functions getNixPlatform and getRedistArch which are needed before the flags
    # attribute set of values and functions is created in the package fixed-point.
    jetsonTargets = {
      description = "List of Jetson targets";
      type = listOf cuda-lib.types.cudaCapability;
      default =
        let
          allJetsonComputeCapabilities = concatMap (
            gpu: optionals gpu.isJetson [ gpu.computeCapability ]
          ) config.data.gpus;
        in
        intersectLists allJetsonComputeCapabilities config.cuda.capabilities;
    };
  };
}
