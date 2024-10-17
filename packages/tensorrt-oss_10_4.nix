{
  backendStdenv,
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cuda_profiler_api,
  cudaMajorMinorVersion,
  fetchFromGitHub,
  flags,
  lib,
  onnx,
  onnx-tensorrt,
  protobuf,
  tensorrt_10_4,
  which,
  python3,
}:
let
  inherit (lib.attrsets) getLib;
  inherit (lib.strings)
    concatMapStringsSep
    cmakeBool
    cmakeFeature
    cmakeOptionType
    ;
  inherit (lib.versions) majorMinor;
  cmakePath = cmakeOptionType "PATH";

  inherit (flags) cudaCapabilities dropDot;
  inherit (tensorrt_10_4.passthru) cudnn;
in

backendStdenv.mkDerivation (finalAttrs: {
  strictDeps = true;

  name = "cuda${cudaMajorMinorVersion}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "tensorrt-oss";
  version = "10.4.0";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "TensorRT";
    rev = "refs/tags/v${finalAttrs.version}";
    # NOTE: We supply our own Onnx and Protobuf, so we do not do a recursive clone.
    hash = "sha256-GAu/VdHrC3UQw9okPexVItLPrRb1m3ZMpCkHNcfzRkE=";
  };

  # Ensure Protobuf is found by CMake.
  # https://github.com/NVIDIA/TensorRT/blob/08ad45bf3df848e722dfdc7d01474b5ba2eff7e9/CMakeLists.txt#L126
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail \
        "include(third_party/protobuf.cmake)" \
        "find_package(Protobuf REQUIRED)" \
      --replace-fail \
        'configure_protobuf(''${PROTOBUF_VERSION})' \
        "find_package(Protobuf REQUIRED)"

    substituteInPlace ./parsers/CMakeLists.txt \
      --replace-fail \
        "add_subdirectory(onnx)" \
        "find_package(ONNX REQUIRED)"
  '';

  # NOTE: NVIDIA's CMake file looks for the C++ compiler through the environment variable and expects a full path.
  # https://github.com/NVIDIA/TensorRT/blob/08ad45bf3df848e722dfdc7d01474b5ba2eff7e9/CMakeLists.txt#L62-L64
  preConfigure = ''
    export CXX="$(which c++)"
  '';

  cudaEnableCmakeFindCudaToolkitSupport = true;

  # Required CMake build arguments are:
  # TRT_LIB_DIR: Path to the TensorRT installation directory containing libraries.
  # TRT_OUT_DIR: Output directory where generated build artifacts will be copied.
  # Optional CMake build arguments:
  # CMAKE_BUILD_TYPE: Specify if binaries generated are for release or debug (contain debug symbols). Values consists of [Release] | Debug
  # PROTOBUF_VERSION: The version of Protobuf to use, for example [3.0.0]. Note: Changing this will not configure CMake to use a system version of Protobuf, it will configure CMake to download and try building that version.
  # CMAKE_TOOLCHAIN_FILE: The path to a toolchain file for cross compilation.
  # TRT_PLATFORM_ID: Bare-metal build (unlike containerized cross-compilation). Currently supported options: x86_64 (default).
  cmakeFlags = [
    (cmakePath "TRT_LIB_DIR" "${getLib tensorrt_10_4}")
    (cmakePath "TRT_OUT_DIR" "$out")
    (cmakeFeature "CUDA_VERSION" cudaMajorMinorVersion)
    (cmakeFeature "CUDNN_VERSION" (majorMinor cudnn.version))
    (cmakeFeature "PROTOBUF_VERSION" (majorMinor protobuf.version))
    (cmakeBool "BUILD_PARSERS" false)
    (cmakeBool "BUILD_PLUGINS" true)
    (cmakeBool "BUILD_SAMPLES" true)
    (cmakeFeature "GPU_ARCHS" (concatMapStringsSep " " dropDot cudaCapabilities))
  ];

  nativeBuildInputs = [
    cmake
    cuda_nvcc
    python3
    which
  ];

  buildInputs = [
    cuda_cudart
    cuda_profiler_api
    cudnn
    onnx
    onnx-tensorrt
    protobuf
    tensorrt_10_4
  ];

  doCheck = true;

  meta = with lib; {
    description = "Open Source Software (OSS) components of NVIDIA TensorRT";
    homepage = "https://github.com/NVIDIA/TensorRT";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = with maintainers; [ connorbaker ] ++ teams.cuda.members;
  };
})
