# Internal hook, used by cudatoolkit and cuda redist packages
# to accommodate automatic CUDAToolkit_ROOT construction
{
  config,
  cudaPackagesConfig,
  lib,
  makeSetupHook,
}:
let
  inherit (cudaPackagesConfig) hostRedistSystem;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id;

  platforms = [
    "aarch64-linux"
    "x86_64-linux"
  ];
  badPlatforms = optionals isBadPlatform platforms;
  badPlatformsConditions = {
    "CUDA support is not enabled" = !config.cudaSupport;
    "Platform is not supported" = hostRedistSystem == "unsupported";
  };
  isBadPlatform = any id (attrValues badPlatformsConditions);
in
makeSetupHook {
  name = "markForCudaToolkitRootHook";
  passthru = { inherit badPlatformsConditions; };
  meta = {
    description = "Setup hook which marks CUDA packages for inclusion in CUDA environment variables";
    inherit badPlatforms platforms;
    maintainers = lib.teams.cuda.members;
  };
} ./markForCudaToolkitRootHook.bash
