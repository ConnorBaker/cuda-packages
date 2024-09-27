{
  lib,
  symlinkJoin,
  backendStdenv,
  cudaOlder,
  cudatoolkit-legacy-runfile,
  cudaMajorMinorVersion,
  cuda_cccl ? null,
  cuda_cudart ? null,
  cuda_cuobjdump ? null,
  cuda_cupti ? null,
  cuda_cuxxfilt ? null,
  cuda_gdb ? null,
  cuda_nvcc ? null,
  cuda_nvdisasm ? null,
  cuda_nvml_dev ? null,
  cuda_nvprune ? null,
  cuda_nvrtc ? null,
  cuda_nvtx ? null,
  cuda_profiler_api ? null,
  cuda_sanitizer_api ? null,
  libcublas ? null,
  libcufft ? null,
  libcurand ? null,
  libcusolver ? null,
  libcusparse ? null,
  libnpp ? null,
}:

let
  inherit (lib.attrsets) getLib;
  inherit (lib.lists) filter map;
  inherit (lib.trivial) pipe;
  getAllOutputs = p: p.all or p;
  hostPackages = filter (p: p != null) [
    cuda_cuobjdump
    cuda_gdb
    cuda_nvcc
    cuda_nvdisasm
    cuda_nvprune
  ];
  targetPackages = filter (p: p != null) [
    cuda_cccl
    cuda_cudart
    cuda_cupti
    cuda_cuxxfilt
    cuda_nvml_dev
    cuda_nvrtc
    cuda_nvtx
    cuda_profiler_api
    cuda_sanitizer_api
    libcublas
    libcufft
    libcurand
    libcusolver
    libcusparse
    libnpp
  ];

  # This assumes we put `cudatoolkit` in `buildInputs` instead of `nativeBuildInputs`:
  allPackages = pipe hostPackages [
    (map (p: p.__spliced.buildHost or p))
    (hostPackages: hostPackages ++ targetPackages)
  ];
in

if cudaOlder "11.4" then
  cudatoolkit-legacy-runfile
else
  symlinkJoin rec {
    name = "cuda${cudaMajorMinorVersion}-cudatoolkit";
    version = cudaMajorMinorVersion;

    paths = builtins.concatMap getAllOutputs allPackages;

    passthru = {
      cc = lib.warn "cudaPackages.cudatoolkit is deprecated, refer to the manual and use splayed packages instead" backendStdenv.cc;
      lib = symlinkJoin {
        inherit name;
        paths = map getLib allPackages;
      };
    };

    meta = with lib; {
      description = "Wrapper substituting the deprecated runfile-based CUDA installation";
      license = licenses.nvidiaCuda;
    };
  }