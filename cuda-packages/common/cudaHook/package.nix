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
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id;

  isBadPlatform = any id (attrValues finalAttrs.passthru.badPlatformsConditions);

  finalAttrs = {
    name = "cuda-hook";

    substitutions.cudaHook = placeholder "out";

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
      badPlatforms = optionals isBadPlatform finalAttrs.meta.platforms;
      maintainers = lib.teams.cuda.members;
    };
  };
in
makeSetupHook finalAttrs ./cuda-hook.sh
