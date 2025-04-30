{
  cmake,
  config,
  cudaPackages,
  lib,
  ninja,
  opencv,
  python3Packages,
  stdenv,
}:
let
  inherit (cudaPackages)
    cuda_cudart
    cuda_nvcc
    cuda_nvrtc
    cuda_nvtx
    cudaStdenv
    flags
    libcublas
    libcusolver
    libcusparse
    tensorrt
    ;
in
stdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;

  pname = "codetr-deformable-attention";
  inherit (python3Packages.codetr) src version;

  sourceRoot = "${finalAttrs.src.name}/codetr/csrc";

  nativeBuildInputs = [
    cmake
    cuda_nvcc
    ninja
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" flags.cmakeCudaArchitecturesString)
    (lib.cmakeFeature "TORCH_CUDA_ARCH_LIST" (lib.concatStringsSep ";" cudaStdenv.cudaCapabilities))
    (lib.cmakeFeature "TENSORRT_LIB_DIR" "${lib.getLib tensorrt}/lib")
    (lib.cmakeFeature "TENSORRT_INCLUDE_DIR" "${lib.getOutput "include" tensorrt}/include")
  ];

  enableParallelBuilding = true;

  buildInputs = [
    cuda_cudart
    cuda_nvrtc
    cuda_nvtx
    libcublas
    libcusolver
    libcusparse
    opencv
    python3Packages.torch
    tensorrt
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib"
    install -Dvm655 libdeformable_attention_plugin.so "$out/lib"
    runHook postInstall
  '';

  # Tests are done in the python module.
  doCheck = false;

  meta = {
    description = "Co-DETR (Detection Transformer) compiled from PyTorch to NVIDIA TensorRT";
    homepage = "https://github.com/anenbergb/Co-DETR-TensorRT";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ connorbaker ];
    broken = !config.cudaSupport;
  };
})
