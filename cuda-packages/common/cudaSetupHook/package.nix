# Currently propagated by cuda_nvcc or cudatoolkit, rather than used directly
{
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
    name = "cuda-setup-hook";

    propagatedBuildInputs = [
      # We add a hook to replace the standard logging functions.
      nixLogWithLevelAndFunctionNameHook
    ];

    substitutions = {
      nixLogWithLevelAndFunctionNameHook = "${nixLogWithLevelAndFunctionNameHook}/nix-support/setup-hook";
      cudaSetupHook = placeholder "out";
    };

    passthru.badPlatformsConditions = {
      "CUDA support is not enabled" = !config.cudaSupport;
      "Platform is not supported" = hostRedistArch == "unsupported";
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
makeSetupHook finalAttrs ./cuda-setup-hook.sh
