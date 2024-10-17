{
  backendStdenv,
  cmake,
  cuda_cccl,
  cuda_cudart,
  cuda_nvcc,
  cuda_profiler_api,
  cuda-lib,
  cudaMajorMinorVersion,
  cudnn,
  fetchFromGitHub,
  flags,
  lib,
  libcublas,
  protobuf,
  tensorrt,
  which,
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

  inherit (flags) cudaCapabilities;
  inherit (cuda-lib.utils) dropDots;
in
backendStdenv.mkDerivation (finalAttrs: {
  strictDeps = true;

  name = "cuda${cudaMajorMinorVersion}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "tensorrt-oss";
  version = "8.5.2";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "TensorRT";
    rev = "refs/tags/${finalAttrs.version}";
    # NOTE: We supply our own Onnx and Protobuf, so we do not do a recursive clone.
    hash = "sha256-2y0kEmGBORc1FJtW2EmXITbiKIZJFyvtRJ/oMnPBivA=";
  };

  # Ensure Protobuf is found by CMake.
  # https://github.com/NVIDIA/TensorRT/blob/08ad45bf3df848e722dfdc7d01474b5ba2eff7e9/CMakeLists.txt#L126
  postPatch = ''
    substituteInPlace ./CMakeLists.txt \
      --replace-fail \
        "include(third_party/protobuf.cmake)" \
        "find_package(Protobuf REQUIRED)" \
      --replace-fail \
        'configure_protobuf(''${PROTOBUF_VERSION})' \
        "find_package(Protobuf REQUIRED)"
  '';

  # NOTE: NVIDIA's CMake file looks for the C++ compiler through the environment variable and expects a full path.
  # https://github.com/NVIDIA/TensorRT/blob/08ad45bf3df848e722dfdc7d01474b5ba2eff7e9/CMakeLists.txt#L62-L64
  preConfigure = ''
    export CXX="$(which c++)"
  '';

  cudaEnableCmakeFindCudaToolkitSupport = true;

  cmakeFlags = [
    (cmakeFeature "TRT_PLATFORM_ID" "aarch64") # Only ever building for Jetsons...
    (cmakePath "TRT_LIB_DIR" "${getLib tensorrt}")
    (cmakePath "TRT_OUT_DIR" "$out")
    (cmakeFeature "CUDA_VERSION" cudaMajorMinorVersion)
    (cmakeFeature "CUDNN_VERSION" (majorMinor cudnn.version))
    (cmakeFeature "PROTOBUF_VERSION" (majorMinor protobuf.version))
    (cmakeBool "BUILD_PARSERS" false) # Cannot build parsers at the same time as plugins and samples, and missing caffe protobuf so build fails.
    (cmakeBool "BUILD_PLUGINS" true)
    (cmakeBool "BUILD_SAMPLES" true)
    (cmakeFeature "GPU_ARCHS" (concatMapStringsSep " " dropDots cudaCapabilities))
  ];

  nativeBuildInputs = [
    cmake
    cuda_nvcc
    which
  ];

  buildInputs = [
    cuda_cccl # <thrust/*>
    cuda_cudart
    cuda_profiler_api
    cudnn
    libcublas
    protobuf
    tensorrt
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
