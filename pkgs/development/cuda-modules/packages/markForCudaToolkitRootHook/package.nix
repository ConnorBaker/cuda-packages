# Internal hook, used by cudatoolkit and cuda redist packages
# to accommodate automatic CUDAToolkit_ROOT construction
{
  arrayUtilities,
  config,
  cudaPackagesConfig,
  lib,
  makeSetupHook,
}:
let
  inherit (cudaPackagesConfig) hostRedistSystem;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id warnIfNot;

  # NOTE: Does not depend on the CUDA package set, so do not use cudaNamePrefix to avoid causing
  # unnecessary / duplicate store paths.
  name = "markForCudaToolkitRootHook";

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
  inherit name;

  propagatedBuildInputs = [ arrayUtilities.occursInArray ];

  passthru = {
    inherit badPlatformsConditions;
    brokenConditions = { };
  };

  meta = {
    description = "Setup hook which marks CUDA packages for inclusion in CUDA environment variables";
    inherit badPlatforms platforms;
    broken =
      warnIfNot config.cudaSupport
        "CUDA support is disabled and you are building a CUDA package (${name}); expect breakage!"
        false;
    maintainers = lib.teams.cuda.members;
  };
} ./markForCudaToolkitRootHook.bash
