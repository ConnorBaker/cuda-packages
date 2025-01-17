# autoAddCudaCompatRunpath hook must be added AFTER `setupCudaHook`. Both
# hooks prepend a path with `libcuda.so` to the `DT_RUNPATH` section of
# patched elf files, but `cuda_compat` path must take precedence (otherwise,
# it doesn't have any effect) and thus appear first. Meaning this hook must be
# executed last.
{
  autoFixElfFiles,
  config,
  cuda_compat,
  cudaConfig,
  cudaStdenv,
  flags,
  lib,
  makeSetupHook,
  nixLogWithLevelAndFunctionNameHook,
}:
let
  inherit (cudaConfig) hostRedistArch;
  inherit (cudaStdenv) cudaNamePrefix;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any optionals;
  inherit (lib.strings) optionalString;
  inherit (lib.trivial) id;

  isBadPlatform = any id (attrValues finalAttrs.passthru.badPlatformsConditions);
  isBroken = any id (attrValues finalAttrs.passthru.brokenConditions);

  finalAttrs = {
    name = "${cudaNamePrefix}-auto-add-cuda-compat-runpath-hook";
    propagatedBuildInputs = [
      # Used in the setup hook
      autoFixElfFiles
      # We add a hook to replace the standard logging functions.
      nixLogWithLevelAndFunctionNameHook
    ];
    substitutions = {
      libcudaPath = optionalString (cuda_compat != null) "${cuda_compat}/compat";
      nixLogWithLevelAndFunctionNameHook = "${nixLogWithLevelAndFunctionNameHook}/nix-support/setup-hook";
    };
    passthru = {
      brokenConditions = {
        "cuda_compat is disabled" = cuda_compat == null;
        "not building for Jetson devices" = !flags.isJetsonBuild;
      };
      badPlatformsConditions = {
        "CUDA support is not enabled" = !config.cudaSupport;
        "Platform is not supported" = hostRedistArch == "unsupported";
      };
    };
    meta = {
      description = "Setup hook which propagates cuda-compat on Jetson devices";
      broken = isBroken;
      platforms = [ "aarch64-linux" ];
      badPlatforms = optionals isBadPlatform finalAttrs.meta.platforms;
      maintainers = lib.teams.cuda.members;
    };
  };
in
makeSetupHook finalAttrs ./auto-add-cuda-compat-runpath.sh
