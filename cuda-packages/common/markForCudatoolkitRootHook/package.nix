# Internal hook, used by cudatoolkit and cuda redist packages
# to accommodate automatic CUDAToolkit_ROOT construction
{
  cudaStdenv,
  config,
  cudaConfig,
  lib,
  makeSetupHook,
  nixLogWithLevelAndFunctionNameHook,
}:
let
  inherit (cudaConfig) hostRedistArch;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id;

  isBadPlatform = any id (attrValues finalAttrs.passthru.badPlatformsConditions);

  finalAttrs = {
    name = "${cudaStdenv.cudaNamePrefix}-mark-for-cudatoolkit-root-hook";
    propagatedBuildInputs = [
      # We add a hook to replace the standard logging functions.
      nixLogWithLevelAndFunctionNameHook
    ];
    substitutions.nixLogWithLevelAndFunctionNameHook = "${nixLogWithLevelAndFunctionNameHook}/nix-support/setup-hook";
    passthru.badPlatformsConditions = {
      "CUDA support is not enabled" = !config.cudaSupport;
      "Platform is not supported" = hostRedistArch == "unsupported";
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
