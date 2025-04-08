# Currently propagated by cuda_nvcc or cudatoolkit, rather than used directly
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
  inherit (lib.lists) any;
  inherit (lib.trivial) id warnIfNot;

  # NOTE: Does not depend on the CUDA package set, so do not use cudaNamePrefix to avoid causing
  # unnecessary / duplicate store paths.
  name = "cudaHook";

  platforms = [
    "aarch64-linux"
    "x86_64-linux"
  ];
  badPlatforms = lib.optionals isBadPlatform platforms;
  badPlatformsConditions = {
    "Platform is not supported" = hostRedistSystem == "unsupported";
  };
  isBadPlatform = any id (attrValues badPlatformsConditions);
in
makeSetupHook {
  inherit name;

  propagatedBuildInputs = [ arrayUtilities.occursInArray ];

  substitutions.cudaHook = placeholder "out";

  passthru = {
    brokenConditions = { };
    inherit badPlatformsConditions;
  };

  meta = {
    description = "Setup hook for CUDA packages";
    inherit badPlatforms platforms;
    broken =
      warnIfNot config.cudaSupport
        "CUDA support is disabled and you are building a CUDA package (${name}); expect breakage!"
        false;
    maintainers = lib.teams.cuda.members;
  };
} ./cudaHook.bash
