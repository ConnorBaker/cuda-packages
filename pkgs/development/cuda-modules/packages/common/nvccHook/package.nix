{
  arrayUtilities,
  autoFixElfFiles,
  callPackages,
  config,
  cuda_nvcc,
  cudaNamePrefix,
  cudaPackagesConfig,
  cudaStdenv,
  lib,
  makeSetupHook,
  patchelf,
  stdenv,
}:
let
  inherit (cuda_nvcc.passthru) nvccHostCCMatchesStdenvCC;
  inherit (cudaPackagesConfig) hostRedistSystem;
  inherit (lib.attrsets) attrValues optionalAttrs;
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id warnIfNot;

  # NOTE: Depends on the CUDA package set, so use cudaNamePrefix.
  name = "${cudaNamePrefix}-nvccHook";

  # TODO(@connorbaker): The setup hook tells CMake not to link paths which include a GCC-specific compiler
  # path from cudaStdenv's host compiler. Generalize this to Clang as well!
  substitutions =
    {
      inherit nvccHostCCMatchesStdenvCC;
    }
    // optionalAttrs (!nvccHostCCMatchesStdenvCC) {
      cudaStdenvCCVersion = cudaStdenv.cc.version;
      cudaStdenvCCHostPlatformConfig = cudaStdenv.hostPlatform.config;
      cudaStdenvCCFullPath = "${cudaStdenv.cc}/bin/${cudaStdenv.cc.targetPrefix}c++";
      cudaStdenvCCUnwrappedCCRoot = cudaStdenv.cc.cc.outPath;
      cudaStdenvCCUnwrappedCCLibRoot = cudaStdenv.cc.cc.lib.outPath;

      stdenvCCVersion = stdenv.cc.version;
      stdenvCCHostPlatformConfig = stdenv.hostPlatform.config;
      stdenvCCFullPath = "${stdenv.cc}/bin/${stdenv.cc.targetPrefix}c++";
      stdenvCCUnwrappedCCRoot = stdenv.cc.cc.outPath;
      stdenvCCUnwrappedCCLibRoot = stdenv.cc.cc.lib.outPath;

      # TODO: Setting cudaArchs means that we have to recompile a large number of packages because `cuda_nvcc`
      # propagates this hook, and so the input derivations change.
      # This wouldn't be an issue if we had content addressed derivations.
      # cudaArchs = cmakeCudaArchitecturesString;
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

  brokenConditions = {
    "nvccHook (currently) only supports GCC for cudaStdenv host compiler" = !cudaStdenv.cc.isGNU;
    "nvccHook (currently) only supports GCC for stdenv host compiler" = !stdenv.cc.isGNU;
  };
  isBroken = any id (attrValues brokenConditions);
in
# TODO: Document breaking change of move from cudaDontCompressFatbin to dontCompressCudaFatbin.
(makeSetupHook {
  inherit name;

  propagatedBuildInputs = [
    autoFixElfFiles
    patchelf
  ];

  inherit substitutions;

  passthru = {
    inherit badPlatformsConditions brokenConditions substitutions;
    tests = {
      dontCompressCudaFatbin = callPackages ./tests/dontCompressCudaFatbin.nix { };
      # TODO(@connorbaker): Rewrite tests.
      # nvccRunpathFixup = callPackages ./tests/nvccRunpathFixup.nix { };
    };
  };

  meta = {
    description = "Setup hook which prevents leaking NVCC host compiler libs into binaries";
    inherit badPlatforms platforms;
    broken =
      warnIfNot config.cudaSupport
        "CUDA support is disabled and you are building a CUDA package (${name}); expect breakage!"
        isBroken;
    maintainers = lib.teams.cuda.members;
  };
} ./nvccHook.bash).overrideAttrs
  (prevAttrs: {
    depsHostHostPropagated = prevAttrs.depsHostHostPropagated or [ ] ++ [
      arrayUtilities.computeFrequencyMap
      arrayUtilities.getRunpathEntries
      arrayUtilities.occursInArray
      arrayUtilities.occursOnlyOrAfterInArray
    ];
  })
