# Currently propagated by cuda_nvcc or cudatoolkit, rather than used directly
{
  config,
  cudaPackagesConfig,
  lib,
  makeSetupHook,
}:
let
  inherit (cudaPackagesConfig) hostRedistSystem;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any;
  inherit (lib.trivial) id;
  isBadPlatform = any id (attrValues badPlatformsConditions);
  platforms = [
    "aarch64-linux"
    "x86_64-linux"
  ];
  badPlatforms = lib.optionals isBadPlatform platforms;
  badPlatformsConditions = {
    "CUDA support is not enabled" = !config.cudaSupport;
    "Platform is not supported" = hostRedistSystem == "unsupported";
  };
in
makeSetupHook {
  name = "cudaHook";

  substitutions.cudaHook = placeholder "out";

  passthru = {
    inherit badPlatformsConditions;
  };

  meta = {
    description = "Setup hook for CUDA packages";
    inherit badPlatforms platforms;
    maintainers = lib.teams.cuda.members;
  };
} ./cudaHook.bash
