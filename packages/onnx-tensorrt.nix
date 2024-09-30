{
  backendStdenv,
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cudaMajorMinorVersion,
  fetchFromGitHub,
  lib,
  onnx,
  protobuf,
  tensorrt_10_4,
  python3,
}:
let
  inherit (lib.strings) cmakeBool cmakeFeature;
in
backendStdenv.mkDerivation (finalAttrs: {
  strictDeps = true;

  name = "cuda${cudaMajorMinorVersion}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "onnx-tensorrt";
  version = "10.4.0";

  src = fetchFromGitHub {
    owner = "onnx";
    repo = "onnx-tensorrt";
    rev = "release/10.4-GA";
    hash = "sha256-ZHWIwPy/iQS6iKAxVL9kKM+KbfzvktFrCElie4Aj8mg=";
  };

  # Ensure Onnx is found by CMake rather than using the vendored version.
  # https://github.com/onnx/onnx-tensorrt/blob/3775e499322eee17c837e27bff6d07af4261767a/CMakeLists.txt#L90
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail \
        "add_subdirectory(third_party/onnx EXCLUDE_FROM_ALL)" \
        "find_package(ONNX REQUIRED)"
  '';

  cmakeFlags = [
    (cmakeBool "BUILD_API_TEST" false) # Missing source files
    (cmakeBool "BUILD_ONNXIFI" false) # Missing source files
    (cmakeFeature "ONNX_NAMESPACE" "onnx") # Should be the same as what we built Onnx with
  ];

  nativeBuildInputs = [
    cmake
    cuda_nvcc
    python3
    protobuf
  ];

  buildInputs = [
    cuda_cudart
    onnx
    protobuf
    tensorrt_10_4
  ];

  doCheck = true;

  meta = with lib; {
    description = "TensorRT backend for Onnx";
    homepage = "https://github.com/onnx/onnx-tensorrt";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = with maintainers; [ connorbaker ] ++ teams.cuda.members;
  };
})
