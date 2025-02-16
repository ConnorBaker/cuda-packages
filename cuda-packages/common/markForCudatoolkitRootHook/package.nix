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

  isBadPlatform = any id (attrValues finalAttrs.passthru.badPlatformsConditions);

  finalAttrs = {
    name = "mark-for-cudatoolkit-root-hook";
    passthru.badPlatformsConditions = {
      "CUDA support is not enabled" = !config.cudaSupport;
      "Platform is not supported" = hostRedistSystem == "unsupported";
    };
    meta = {
      description = "Setup hook which marks CUDA packages for inclusion in CUDA environment variables";
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      badPlatforms = optionals isBadPlatform finalAttrs.meta.platforms;
      maintainers = lib.teams.cuda.members;
    };
  };
in
makeSetupHook finalAttrs ./mark-for-cudatoolkit-root-hook.sh
