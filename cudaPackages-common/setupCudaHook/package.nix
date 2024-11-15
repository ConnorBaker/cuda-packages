# Currently propagated by cuda_nvcc or cudatoolkit, rather than used directly
{
  backendStdenv,
  flags,
  lib,
  makeSetupHook,
}:
let
  inherit (flags) cmakeCudaArchitecturesString cudaNamePrefix;
in
makeSetupHook {
  name = "${cudaNamePrefix}-setup-cuda-hook";

  substitutions = {
    # Required in addition to ccRoot as otherwise bin/gcc is looked up
    # when building CMakeCUDACompilerId.cu
    ccFullPath = "${backendStdenv.cc}/bin/${backendStdenv.cc.targetPrefix}c++";
    cudaArchs = cmakeCudaArchitecturesString;
    setupCudaHook = placeholder "out";
  };

  meta = {
    description = "Setup hook for CUDA packages";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = lib.teams.cuda.members;
  };
} ./setup-cuda-hook.sh
