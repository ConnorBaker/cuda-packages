# TODO(@connorbaker): Package samples as test cases, and make a bin output for tools.
{
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cuda_profiler_api,
  cudaMajorMinorVersion,
  cudaStdenv,
  cudnn,
  fetchFromGitHub,
  flags,
  lib,
  ninja,
  protobuf_25,
  tensorrt,
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
  # TODO: Add to cuda-lib or upstream.
  cmakePath = cmakeOptionType "PATH";

  inherit (flags) cudaCapabilities;
  inherit (lib.cuda.utils) dropDots;
in
cudaStdenv.mkDerivation (finalAttrs: {
  pname = "tensorrt-oss";
  version = "10.6.0";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "TensorRT";
    rev = "refs/tags/v${finalAttrs.version}";
    # NOTE: We supply our own Onnx and Protobuf, so we do not do a recursive clone.
    hash = "sha256-nnzicyCjVqpAonIhx3u9yNnoJkZ0XXjJ8oxQH+wfrtE=";
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
    export CXX="${cudaStdenv.cc}/bin/${cudaStdenv.cc.targetPrefix}c++"
  '';

  cudaEnableCmakeFindCudaToolkitSupport = true;

  cmakeFlags = [
    (cmakeFeature "TRT_PLATFORM_ID" cudaStdenv.hostPlatform.parsed.cpu.name)
    (cmakePath "TRT_LIB_DIR" "${getLib tensorrt}")
    (cmakePath "TRT_OUT_DIR" "$out")
    (cmakeFeature "CUDA_VERSION" cudaMajorMinorVersion)
    (cmakeFeature "CUDNN_VERSION" (majorMinor cudnn.version))
    (cmakeFeature "PROTOBUF_VERSION" (majorMinor protobuf_25.version))
    (cmakeBool "BUILD_PARSERS" false) # Cannot build parsers at the same time as plugins and samples, and missing caffe protobuf so build fails.
    (cmakeBool "BUILD_PLUGINS" true)
    (cmakeBool "BUILD_SAMPLES" true)
    (cmakeFeature "GPU_ARCHS" (concatMapStringsSep " " dropDots cudaCapabilities))
  ];

  nativeBuildInputs = [
    cmake
    cuda_nvcc
    ninja
  ];

  buildInputs = [
    cuda_cudart
    cuda_profiler_api
    cudnn
    protobuf_25
    tensorrt
  ];

  # For some reason, the two include directorires we need aren't copied to the output.
  # onnx-tensorrt requires it, so we copy it manually.
  postInstall =
    ''
      pushd "$NIX_BUILD_TOP/$sourceRoot"
      cp -r ./include "$out/"
      pushd "python"
      mkdir -p "$out/python"
      cp -r ./include "$out/python/"
      popd
      popd
    ''
    # Create a symlink for the Onnx header files in include/onnx
    # NOTE(@connorbaker): This is shared with the tensorrt override, with the `include` output swapped with `out`.
    # When updating one, check if the other should be updated.
    + ''
      mkdir "$out/include/onnx"
      pushd "$out/include"
      ln -srt "$out/include/onnx/" NvOnnx*.h
      popd
    '';

  doCheck = true;

  meta = with lib; {
    description = "Open Source Software (OSS) components of NVIDIA TensorRT";
    homepage = "https://github.com/NVIDIA/TensorRT";
    license = licenses.asl20;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = (with maintainers; [ connorbaker ]) ++ teams.cuda.members;
  };
})
