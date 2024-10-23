# Currently propagated by cuda_nvcc or cudatoolkit, rather than used directly
{
  backendStdenv,
  flags,
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
} ./setup-cuda-hook.sh
