# Currently propagated by cuda_nvcc or cudatoolkit, rather than used directly
{
  config,
  cuda_nvcc,
  cudaConfig,
  flags,
  lib,
  makeSetupHook,
  nixLogWithLevelAndFunctionNameHook,
}:
let
  inherit (cuda_nvcc.passthru.nvccStdenv) cc hostPlatform;
  inherit (cudaConfig) hostRedistArch;
  inherit (flags) cmakeCudaArchitecturesString;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id;

  isBadPlatform = any id (attrValues finalAttrs.passthru.badPlatformsConditions);

  finalAttrs = {
    name = "setup-cuda-hook";

    propagatedBuildInputs = [
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
      unwrappedCCRoot = cc.cc.outPath;
      unwrappedCCLibRoot = cc.cc.lib.outPath;
      hostPlatformConfig = hostPlatform.config;
      cudaArchs = cmakeCudaArchitecturesString;
      nixLogWithLevelAndFunctionNameHook = "${nixLogWithLevelAndFunctionNameHook}/nix-support/setup-hook";
      setupCudaHook = placeholder "out";
    };

    passthru.badPlatformsConditions = {
      "CUDA support is not enabled" = !config.cudaSupport;
      "Platform is not supported" = hostRedistArch == "unsupported";
    };

    meta = {
      description = "Setup hook for CUDA packages";
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      badPlatforms = optionals isBadPlatform finalAttrs.meta.platforms;
      maintainers = lib.teams.cuda.members;
    };
  };
in
makeSetupHook finalAttrs ./setup-cuda-hook.sh
