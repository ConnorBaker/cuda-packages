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
}:
let
  inherit (cuda_nvcc.passthru) nvccHostCCMatchesStdenvCC;
  inherit (cudaPackagesConfig) hostRedistSystem;
  inherit (cudaStdenv) cc hostPlatform;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id warnIfNot;

  # NOTE: Depends on the CUDA package set, so use cudaNamePrefix.
  name = "${cudaNamePrefix}-nvccHook";

  # TODO(@connorbaker): The setup hook tells CMake not to link paths which include a GCC-specific compiler
  # path from cudaStdenv's host compiler. Generalize this to Clang as well!
  substitutions = {
    inherit nvccHostCCMatchesStdenvCC;
    ccFullPath = "${cc}/bin/${cc.targetPrefix}c++";
    ccVersion = cc.version;
    # TODO: Setting cudaArchs means that we have to recompile a large number of packages because `cuda_nvcc`
    # propagates this hook, and so the input derivations change.
    # cudaArchs = cmakeCudaArchitecturesString;
    hostPlatformConfig = hostPlatform.config;
    unwrappedCCRoot = cc.cc.outPath;
    unwrappedCCLibRoot = cc.cc.lib.outPath;
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
# TODO: Document breaking change of move from cudaDontCompressFatbin to dontCompressCudaFatbin.
(makeSetupHook {
  inherit name;

  propagatedBuildInputs = [ autoFixElfFiles ];

  inherit substitutions;

  passthru = {
    inherit badPlatformsConditions substitutions;
    brokenConditions = { };
    tests = {
      dontCompressCudaFatbin = callPackages ./tests/dontCompressCudaFatbin.nix { };
      nvccHookOrderCheckPhase = callPackages ./tests/nvccHookOrderCheckPhase.nix { };
      nvccRunpathCheck = callPackages ./tests/nvccRunpathCheck.nix { };
    };
  };

  meta = {
    description = "Setup hook which prevents leaking NVCC host compiler libs into binaries";
    inherit badPlatforms platforms;
    broken =
      warnIfNot config.cudaSupport
        "CUDA support is disabled and you are building a CUDA package (${name}); expect breakage!"
        false;
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
