{
  cmake,
  cuda_cccl,
  cuda_cudart,
  cuda_nvcc,
  lib,
  libcublas,
  stdenv,
}:
let
  inherit (lib.fileset) toSource unions;
  inherit (lib.strings) cmakeBool;
in
stdenv.mkDerivation {
  pname = "saxpy";
  version = "unstable-2023-07-11";

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
}
