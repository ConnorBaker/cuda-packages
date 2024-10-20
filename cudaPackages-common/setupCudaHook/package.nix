# Currently propagated by cuda_nvcc or cudatoolkit, rather than used directly
{
  backendStdenv,
  cudaMajorMinorVersion,
  flags,
  makeSetupHook,
}:
makeSetupHook {
  name = "cuda${cudaMajorMinorVersion}-setup-cuda-hook";

  substitutions = {
    # Required in addition to ccRoot as otherwise bin/gcc is looked up
    # when building CMakeCUDACompilerId.cu
    ccFullPath = "${backendStdenv.cc}/bin/${backendStdenv.cc.targetPrefix}c++";
    cudaArchs = flags.cmakeCudaArchitecturesString;
    setupCudaHook = placeholder "out";
  };
} ./setup-cuda-hook.sh
