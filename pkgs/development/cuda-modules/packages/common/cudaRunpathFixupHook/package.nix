{
  addDriverRunpath,
  arrayUtilities,
  autoFixElfFiles,
  callPackages,
  config,
  cuda_compat,
  cuda_cudart,
  cudaNamePrefix,
  cudaPackagesConfig,
  lib,
  makeSetupHook,
}:
let
  inherit (cudaPackagesConfig) hasJetsonCudaCapability hostRedistSystem;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id warnIfNot;
  inherit (lib.strings) optionalString;

  # NOTE: Depends on the CUDA package set, so use cudaNamePrefix.
  name = "${cudaNamePrefix}-cudaRunpathFixupHook";

  substitutions = {
    cudaCompatLibDir = optionalString (
      hasJetsonCudaCapability && cuda_compat != null
    ) "${cuda_compat.outPath}/compat";
    # The stubs are symlinked from lib/stubs into lib so autoPatchelf can find them.
    cudaStubLibDir = "${cuda_cudart.stubs.outPath}/lib";
    driverLibDir = "${addDriverRunpath.driverLink}/lib";
  };

  platforms = [
    "aarch64-linux"
    "x86_64-linux"
  ];
  badPlatforms = optionals isBadPlatform platforms;
  badPlatformsConditions = {
    "CUDA support is not enabled" = !config.cudaSupport;
    "Platform is not supported" = hostRedistSystem == "unsupported";
  };
  isBadPlatform = any id (attrValues badPlatformsConditions);
in
# TODO: Are there other libraries which provide stubs which we should replace with the driver runpath?
# E.g., libnvidia-ml.so is provided by a stub library in cuda_nvml_dev.
makeSetupHook {
  inherit name;

  propagatedBuildInputs = [
    # Used in the setup hook
    autoFixElfFiles
    arrayUtilities.occursOnlyOrAfterInArray
  ];

  inherit substitutions;

  passthru = {
    inherit badPlatformsConditions substitutions;
    brokenConditions = { };
    tests = {
      cudaRunpathFixup = callPackages ./tests/cudaRunpathFixup.nix { };
      cudaRunpathFixupHookOrderCheckPhase =
        callPackages ./tests/cudaRunpathFixupHookOrderCheckPhase.nix
          { };
    };
  };

  meta = {
    description = "Setup hook which ensures correct ordering of CUDA-related runpaths";
    inherit badPlatforms platforms;
    broken =
      warnIfNot config.cudaSupport
        "CUDA support is disabled and you are building a CUDA package (${name}); expect breakage!"
        false;
    maintainers = lib.teams.cuda.members;
  };
} ./cudaRunpathFixupHook.bash
