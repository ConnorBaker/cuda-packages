{
  autoFixElfFiles,
  config,
  cuda_nvcc,
  cudaConfig,
  flags,
  lib,
  makeSetupHook,
  nixLogWithLevelAndFunctionNameHook,

  # passthru.tests
  autoPatchelfHook,
  cuda_cudart,
  nvccHook,
  patchelf,
  runCommand,
  stdenv,
  testers,
}:
let
  inherit (cuda_nvcc.passthru.nvccStdenv) cc hostPlatform;
  inherit (cudaConfig) hostRedistArch;
  inherit (flags) cmakeCudaArchitecturesString;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id;

  isBadPlatform = any id (attrValues finalAttrs.passthru.badPlatformsConditions);

  # TODO: Document breaking change of move from cudaDontCompressFatbin to dontCompressCudaFatbin.

  finalAttrs = {
    name = "nvcc-hook";

    propagatedBuildInputs = [
      # Used in the setup hook
      autoFixElfFiles
      # We add a hook to replace the standard logging functions.
      nixLogWithLevelAndFunctionNameHook
    ];

    # TODO(@connorbaker): The setup hook tells CMake not to link paths which include a GCC-specific compiler
    # path from nvccStdenv's host compiler. Generalize this to Clang as well!
    substitutions = {
      # Required in addition to ccRoot as otherwise bin/gcc is looked up
      # when building CMakeCUDACompilerId.cu
      ccFullPath = "${cc}/bin/${cc.targetPrefix}c++";
      ccVersion = cc.version;
      cudaArchs = cmakeCudaArchitecturesString;
      hostPlatformConfig = hostPlatform.config;
      nixLogWithLevelAndFunctionNameHook = "${nixLogWithLevelAndFunctionNameHook}/nix-support/setup-hook";
      unwrappedCCRoot = cc.cc.outPath;
      unwrappedCCLibRoot = cc.cc.lib.outPath;
    };

    passthru = {
      inherit (finalAttrs) substitutions;
      badPlatformsConditions = {
        "CUDA support is not enabled" = !config.cudaSupport;
        "Platform is not supported" = hostRedistArch == "unsupported";
      };
      tests = import ./tests.nix {
        inherit
          autoPatchelfHook
          cuda_cudart
          cuda_nvcc
          lib
          nvccHook
          patchelf
          runCommand
          stdenv
          testers
          ;
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
  };
in
makeSetupHook finalAttrs ./nvcc-hook.sh
