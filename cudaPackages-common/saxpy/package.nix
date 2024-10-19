{
  backendStdenv,
  cmake,
  cuda_cccl ? null, # Only available from CUDA 12.0.
  cuda_cudart,
  cuda_nvcc,
  cudaAtLeast,
  cudaMajorMinorVersion,
  lib,
  libcublas,
}:
let
  inherit (lib.fileset) toSource unions;
  inherit (lib.lists) optionals;
  inherit (lib.strings) cmakeBool;
in
backendStdenv.mkDerivation (finalAttrs: {
  name = "cuda${cudaMajorMinorVersion}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "saxpy";
  version = "unstable-2023-07-11";

  src = toSource {
    root = ./.;
    fileset = unions [
      ./CMakeLists.txt
      ./saxpy.cu
    ];
  };

  __structuredAttrs = true;
  strictDeps = true;

  nativeBuildInputs = [
    cmake
    cuda_nvcc
  ];

  buildInputs = [
    cuda_cudart
    libcublas
  ] ++ optionals (cudaAtLeast "12.0") [ cuda_cccl ];

  cmakeFlags = [
    (cmakeBool "CMAKE_VERBOSE_MAKEFILE" true)
  ];

  passthru.gpuCheck = finalAttrs.finalPackage.overrideAttrs (prevAttrs: {
    requiredSystemFeatures = [ "cuda" ];
    doInstallCheck = true;
    postInstallCheck = ''
      $out/bin/${prevAttrs.meta.mainProgram}
    '';
  });

  meta = {
    description = "Simple (Single-precision AX Plus Y) FindCUDAToolkit.cmake example for testing cross-compilation";
    license = lib.licenses.mit;
    maintainers = lib.teams.cuda.members;
    mainProgram = "saxpy";
    platforms = [
      "aarch64-linux"
      "ppc64le-linux"
      "x86_64-linux"
    ];
  };
})
