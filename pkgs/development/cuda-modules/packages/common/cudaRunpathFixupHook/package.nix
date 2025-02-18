{
  addDriverRunpath,
  arrayUtilitiesHook,
  autoFixElfFiles,
  callPackages,
  config,
  cuda_compat,
  cuda_cudart,
  cudaPackagesConfig,
  lib,
  makeSetupHook,
}:
let
  inherit (cudaPackagesConfig) hasJetsonCudaCapability hostRedistSystem;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id;
  inherit (lib.strings) optionalString;

  isBadPlatform = any id (attrValues finalAttrs.passthru.badPlatformsConditions);

  # TODO: Are there other libraries which provide stubs which we should replace with the driver runpath?
  # E.g., libnvidia-ml.so is provided by a stub library in cuda_nvml_dev.

  finalAttrs = {
    name = "cuda-runpath-fixup-hook";

    propagatedBuildInputs = [
      # Used in the setup hook
      autoFixElfFiles
      arrayUtilitiesHook
    ];

    substitutions = {
      cudaCompatLibDir = optionalString (
        hasJetsonCudaCapability && cuda_compat != null
      ) "${cuda_compat.outPath}/compat";
      # The stubs are symlinked from lib/stubs into lib so autoPatchelf can find them.
      cudaStubLibDir = "${cuda_cudart.stubs.outPath}/lib";
      driverLibDir = "${addDriverRunpath.driverLink}/lib";
    };

    passthru = {
      inherit (finalAttrs) substitutions;
      badPlatformsConditions = {
        "CUDA support is not enabled" = !config.cudaSupport;
        "Platform is not supported" = hostRedistSystem == "unsupported";
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
