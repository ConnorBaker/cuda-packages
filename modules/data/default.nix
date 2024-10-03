{
  config,
  cuda-lib,
  lib,
  pkgs,
  ...
}:
let
  inherit (cuda-lib.utils) mkOptions;
  inherit (lib.attrsets) attrNames attrValues;
  inherit (lib.lists)
    concatMap
    filter
    intersectLists
    optionals
    ;
  inherit (lib.strings) versionOlder;
  inherit (lib.trivial) flip pipe;
  inherit (lib.types) listOf nonEmptyListOf;
in
{
  imports = [
    ./cudatoolkit-runfile-releases.nix
    ./gpus.nix
    ./nvcc-compatibilities.nix
  ];
  options.data = mkOptions {
    cudaRedistMajorMinorPatchVersions = {
      description = ''
        List of CUDA major.minor.patch versions provided by the redist packages

        Notable: CUDA versions from 11.4.4 are available as redist packages.
      '';
      type = nonEmptyListOf cuda-lib.types.majorMinorPatchVersion;
      default = attrNames config.redists.cuda.versionedManifests;
    };
    cudatoolkitMajorMinorPatchVersions = {
      description = ''
        List of CUDA major.minor.patch versions provided by the runfile installer

        Notable: CUDA versions prior to 11.4.4 are not available as redist packages.
      '';
      type = nonEmptyListOf cuda-lib.types.majorMinorPatchVersion;
      default = pipe config.data.cudatoolkitRunfileReleases [
        attrValues
        (map ({ version, ... }: cuda-lib.utils.majorMinorPatch version))
        (filter (flip versionOlder "11.4.0"))
      ];
    };
    # These versions typically have at least three components.
    # TODO(@connorbaker): this assumption is no longer correct.
    # NOTE: Because the python script which produces the index takes only the latest minor version for each major
    # release, there's no way for us to get collisions in creating the package sets (which are versioned by major and
    # minor releases).
    cudaMajorMinorPatchVersions = {
      description = ''
        List of CUDA major.minor.patch versions available across runfile installers and redist packages
      '';
      type = nonEmptyListOf cuda-lib.types.majorMinorPatchVersion;
      default =
        config.data.cudatoolkitMajorMinorPatchVersions ++ config.data.cudaRedistMajorMinorPatchVersions;
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
        intersectLists allJetsonComputeCapabilities (pkgs.config.cudaCapabilities or [ ]);
    };
  };
}
