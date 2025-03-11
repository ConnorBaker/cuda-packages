# Currently propagated by cuda_nvcc or cudatoolkit, rather than used directly
{
  config,
  cudaPackagesConfig,
  lib,
  makeSetupHook',
}:
let
  inherit (cudaPackagesConfig) hostRedistSystem;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any;
  inherit (lib.trivial) id;
in
makeSetupHook' (
  finalAttrs:
  let
    isBadPlatform = any id (attrValues finalAttrs.passthru.badPlatformsConditions);
  in
  {
    name = "cudaHook";

    script = ./cudaHook.bash;

    replacements.cudaHook = placeholder "out";

    passthru.badPlatformsConditions = {
      "CUDA support is not enabled" = !config.cudaSupport;
      "Platform is not supported" = hostRedistSystem == "unsupported";
    };

    meta = {
      description = "Setup hook for CUDA packages";
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      badPlatforms = lib.optionals isBadPlatform finalAttrs.meta.platforms;
      maintainers = lib.teams.cuda.members;
    };
  }
)
