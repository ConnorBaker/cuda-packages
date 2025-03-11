{
  addDriverRunpath,
  arrayUtilities,
  autoFixElfFiles,
  callPackages,
  config,
  cuda_compat,
  cuda_cudart,
  cudaPackagesConfig,
  lib,
  makeSetupHook',
}:
let
  inherit (cudaPackagesConfig) hasJetsonCudaCapability hostRedistSystem;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id;
  inherit (lib.strings) optionalString;

  replacements = {
    cudaCompatLibDir = optionalString (
      hasJetsonCudaCapability && cuda_compat != null
    ) "${cuda_compat.outPath}/compat";
    # The stubs are symlinked from lib/stubs into lib so autoPatchelf can find them.
    cudaStubLibDir = "${cuda_cudart.stubs.outPath}/lib";
    driverLibDir = "${addDriverRunpath.driverLink}/lib";
  };
in
# TODO: Are there other libraries which provide stubs which we should replace with the driver runpath?
# E.g., libnvidia-ml.so is provided by a stub library in cuda_nvml_dev.
makeSetupHook' (
  finalAttrs:
  let
    isBadPlatform = any id (attrValues finalAttrs.passthru.badPlatformsConditions);
  in
  {
    name = "cudaRunpathFixupHook";

    script = ./cudaRunpathFixupHook.bash;

    nativeBuildInputs = [
      # Used in the setup hook
      autoFixElfFiles
      arrayUtilities.occursOnlyOrAfterInArray
    ];

    inherit replacements;

    passthru = {
      inherit replacements;
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
  }
)
