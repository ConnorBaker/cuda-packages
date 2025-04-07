{
  cmake,
  cuda_cccl,
  cuda_cudart,
  cuda_nvcc,
  cudaNamePrefix,
  flags,
  lib,
  libcublas,
  stdenv,
}:
let
  inherit (lib.fileset) toSource unions;
  inherit (lib.strings) cmakeBool cmakeFeature;
in
stdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;

  name = "${cudaNamePrefix}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "saxpy";
  version = "0-unstable-2023-07-11";

  src = toSource {
    root = ./.;
    fileset = unions [
      ./CMakeLists.txt
      ./saxpy.cu
    ];
  };

  nativeBuildInputs = [
    cmake
    cuda_nvcc
  ];

  buildInputs = [
    cuda_cccl
    cuda_cudart
    libcublas
  ];

  cmakeFlags = [
    (cmakeBool "CMAKE_VERBOSE_MAKEFILE" true)
    (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" flags.cmakeCudaArchitecturesString)
  ];

  meta = {
    description = "Simple (Single-precision AX Plus Y) FindCUDAToolkit.cmake example for testing cross-compilation";
    license = lib.licenses.mit;
    maintainers = lib.teams.cuda.members;
    mainProgram = "saxpy";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
