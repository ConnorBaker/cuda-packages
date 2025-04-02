{ config, lib, ... }:
{
  cuda_cccl.outputs = [
    "out"
    "dev"
    "include"
    "lib"
  ];
  cuda_compat = { };
  cuda_cudart.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "static"
    "stubs"
  ];
  cuda_cuobjdump.outputs = [
    "out"
    "bin"
  ];
  cuda_cupti.outputs =
    [
      "out"
      "dev"
      "include"
      "lib"
      "sample"
    ]
    ++ lib.optionals (config.hostNixSystem == "x86_64-linux") [
      "static"
    ];
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
  cuda_nvrtc.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "static"
    "stubs"
  ];
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
  imex = { };
  libcublas.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "static"
    "stubs"
  ];
  libcudla.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "stubs"
  ];
  libcufft.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "static"
    "stubs"
  ];
  libcufile.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "sample"
    "static"
  ];
  libcurand.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "static"
    "stubs"
  ];
  libcusolver.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "static"
    "stubs"
  ];
  libcusparse.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "static"
    "stubs"
  ];
  libnpp.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "static"
    "stubs"
  ];
  libnvidia_nscq.outputs = [
    "out"
    "lib"
  ];
  libnvjitlink.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "static"
    "stubs"
  ];
  libnvjpeg.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "static"
    "stubs"
  ];
  nsight_compute.outputs = [
    "out"
    "bin"
  ];
  nsight_systems.outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "static"
    "stubs"
  ];
  nvidia_fs = { };
}
