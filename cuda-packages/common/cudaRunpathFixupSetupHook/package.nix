{
  addDriverRunpath,
  autoFixElfFiles,
  config,
  cuda_compat,
  cuda_cudart,
  cudaConfig,
  flags,
  lib,
  makeSetupHook,
  nixLogWithLevelAndFunctionNameHook,
}:
let
  inherit (cudaConfig) hostRedistArch;
  inherit (flags) isJetsonBuild;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id;
  inherit (lib.strings) optionalString;

  isBadPlatform = any id (attrValues finalAttrs.passthru.badPlatformsConditions);

  finalAttrs = {
    name = "cuda-runpath-fixup-setup-hook";

    propagatedBuildInputs = [
      # Used in the setup hook
      autoFixElfFiles
      # We add a hook to replace the standard logging functions.
      nixLogWithLevelAndFunctionNameHook
    ];

    substitutions = {
      cudaCompatDir = optionalString (isJetsonBuild && cuda_compat != null) "${cuda_compat.outPath}/compat";
      # The stubs are symlinked from lib/stubs into lib so autoPatchelf can find them.
      cudaStubDir = "${cuda_cudart.stubs.outPath}/lib";
      driverDir = "${addDriverRunpath.driverLink}/lib";
      nixLogWithLevelAndFunctionNameHook = "${nixLogWithLevelAndFunctionNameHook}/nix-support/setup-hook";
    };

    passthru.badPlatformsConditions = {
      "CUDA support is not enabled" = !config.cudaSupport;
      "Platform is not supported" = hostRedistArch == "unsupported";
    };

    meta = {
      description = "Setup hook which ensures correct ordering of CUDA-related runpaths";
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      badPlatforms = optionals isBadPlatform finalAttrs.meta.platforms;
      maintainers = lib.teams.cuda.members;
    };
  };
in
makeSetupHook finalAttrs ./cuda-runpath-fixup-setup-hook.sh
