{
  addDriverRunpath,
  arrayUtilitiesHook,
  autoFixElfFiles,
  callPackages,
  config,
  cuda_compat,
  cuda_cudart,
  cudaConfig,
  flags,
  lib,
  makeSetupHook,
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
    name = "cuda-runpath-fixup-hook";

    propagatedBuildInputs = [
      # Used in the setup hook
      autoFixElfFiles
      arrayUtilitiesHook
    ];

    substitutions = {
      cudaCompatLibDir = optionalString (
        isJetsonBuild && cuda_compat != null
      ) "${cuda_compat.outPath}/compat";
      # The stubs are symlinked from lib/stubs into lib so autoPatchelf can find them.
      cudaStubLibDir = "${cuda_cudart.stubs.outPath}/lib";
      driverLibDir = "${addDriverRunpath.driverLink}/lib";
    };

    passthru = {
      inherit (finalAttrs) substitutions;
      badPlatformsConditions = {
        "CUDA support is not enabled" = !config.cudaSupport;
        "Platform is not supported" = hostRedistArch == "unsupported";
      };
      tests = {
        cudaRunpathFixup = callPackages ./tests/cudaRunpathFixup.nix { };
        cudaRunpathFixupHookOrderCheckPhase =
          callPackages ./tests/cudaRunpathFixupHookOrderCheckPhase.nix
            { };
      };
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
makeSetupHook finalAttrs ./cuda-runpath-fixup-hook.sh
