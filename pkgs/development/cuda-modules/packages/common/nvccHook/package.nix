{
  arrayUtilities,
  autoFixElfFiles,
  callPackages,
  config,
  cuda_nvcc,
  cudaPackagesConfig,
  lib,
  makeSetupHook',
}:
let
  inherit (cuda_nvcc.passthru) nvccHostCCMatchesStdenvCC;
  inherit (cuda_nvcc.passthru.nvccStdenv) cc hostPlatform;
  inherit (cudaPackagesConfig) hostRedistSystem;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id;

  # TODO(@connorbaker): The setup hook tells CMake not to link paths which include a GCC-specific compiler
  # path from nvccStdenv's host compiler. Generalize this to Clang as well!
  replacements = {
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
in
# TODO: Document breaking change of move from cudaDontCompressFatbin to dontCompressCudaFatbin.
makeSetupHook' (
  finalAttrs:
  let
    isBadPlatform = any id (attrValues finalAttrs.passthru.badPlatformsConditions);
  in
  {
    name = "nvccHook";

    script = ./nvccHook.bash;

    nativeBuildInputs = [
      # Used in the setup hook
      autoFixElfFiles
      arrayUtilities.occursOnlyOrAfterInArray
      arrayUtilities.computeFrequencyMap
      arrayUtilities.getRunpathEntries
    ];

    inherit replacements;

    passthru = {
      inherit replacements;
      badPlatformsConditions = {
        "CUDA support is not enabled" = !config.cudaSupport;
        "Platform is not supported" = hostRedistSystem == "unsupported";
      };
      tests = {
        dontCompressCudaFatbin = callPackages ./tests/dontCompressCudaFatbin.nix { };
        nvccHookOrderCheckPhase = callPackages ./tests/nvccHookOrderCheckPhase.nix { };
        nvccRunpathCheck = callPackages ./tests/nvccRunpathCheck.nix { };
      };
    };

    meta = {
      description = "Setup hook which prevents leaking NVCC host compiler libs into binaries";
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      badPlatforms = optionals isBadPlatform finalAttrs.meta.platforms;
      maintainers = lib.teams.cuda.members;
    };
  }
)
