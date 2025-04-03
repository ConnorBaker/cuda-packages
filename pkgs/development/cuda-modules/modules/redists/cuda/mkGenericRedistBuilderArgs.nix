{
  config,
  lib,
  manifest,
  ...
}:
let
  fullLib = [
    "out"
    "dev"
    "include"
    "lib"
    "static"
  ];
  fullLibWithStubs = fullLib ++ [ "stubs" ];
in
{
  cuda_cccl.outputs = [
    "out"
    "dev"
    "include"
    "lib"
  ];
  cuda_compat = { };
  cuda_cudart.outputs = fullLibWithStubs;
  cuda_cuobjdump.outputs = [
    "out"
    "bin"
  ];
  cuda_cupti.outputs = fullLib ++ lib.optionals (config.hostNixSystem == "x86_64-linux") [ "static" ];
  cuda_cuxxfilt.outputs = [
    "out"
    "bin"
    "dev"
    "include"
    "static"
  ];
  cuda_demo_suite = { };
  cuda_documentation = { };
  cuda_gdb.outputs = [
    "out"
    "bin"
  ];
  cuda_nsight.outputs = [
    "out"
    "bin"
  ];
  # NOTE: Restrict cuda_nvcc to a single output for now to avoid breaking some consumers
  # which expect NVCC to be within a single directory structure.
  cuda_nvcc.outputs = [
    "out"
    # "bin"
    # "dev"
    # "include"
    # "static"
  ];
  cuda_nvdisasm.outputs = [
    "out"
    "bin"
  ];
  cuda_nvml_dev.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "stubs"
  ];
  cuda_nvprof.outputs = [
    "out"
    "bin"
    "lib"
  ];
  cuda_nvprune.outputs = [
    "out"
    "bin"
  ];
  cuda_nvrtc.outputs = fullLibWithStubs;
  cuda_nvtx.outputs = [
    "out"
    "dev"
    "include"
    "lib"
  ];
  cuda_nvvp.outputs = [
    "out"
    "bin"
  ];
  cuda_opencl.outputs = [
    "out"
    "dev"
    "include"
    "lib"
  ];
  cuda_profiler_api.outputs = [
    "out"
    "dev"
    "include"
  ];
  cuda_sanitizer_api.outputs = [
    "out"
    "bin"
  ];
  fabricmanager.outputs = [
    "out"
    "bin"
    "dev"
    "include"
    "lib"
  ];
  libcublas.outputs = fullLibWithStubs;
  libcudla.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "stubs"
  ];
  libcufft.outputs = fullLibWithStubs;
  libcufile.outputs = fullLib ++ [ "sample" ];
  libcurand.outputs = fullLibWithStubs;
  libcusolver.outputs = fullLibWithStubs;
  libcusparse.outputs = fullLibWithStubs;
  libnpp.outputs = fullLibWithStubs;
  libnvidia_nscq.outputs = [
    "out"
    "lib"
  ];
  libnvjitlink.outputs = fullLibWithStubs;
  libnvjpeg.outputs = fullLibWithStubs;
  nsight_compute.outputs = [
    "out"
    "bin"
  ];
  nsight_systems.outputs = fullLibWithStubs;
  nvidia_fs = { };
}
// lib.optionalAttrs (manifest ? imex) { imex = { }; }
