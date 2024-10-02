{
  backendStdenv,
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cudaMajorMinorVersion,
  fetchFromGitHub,
  lib,
  onnx_1_12,
  protobuf_21,
  tensorrt_8_5_2,
  python3,
}:
let
  inherit (lib.strings) cmakeBool cmakeFeature;
in
backendStdenv.mkDerivation (finalAttrs: {
  strictDeps = true;

  name = "cuda${cudaMajorMinorVersion}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "onnx-tensorrt";
  version = "8.5.0";

  src = fetchFromGitHub {
    owner = "onnx";
    repo = "onnx-tensorrt";
    rev = "refs/tags/release/8.5-GA";
    hash = "sha256-UPFHw4ode+RNog2c665u2wjNhjMn6Y3dl7wiw6HptlM=";
  };

  # Use our custom CMakeLists which:
  # - re-uses our Onnx instead of the vendored copy
  # - removes nvonnxparser_static which caused linked errors because it tried to link against libraries provided by
  #   the driver
  # - links samples against nvonnxparser instead of nvonnxparser_static
  postPatch = ''
    rm CMakeLists.txt
    cp ${./CMakeLists.txt} CMakeLists.txt
  '';

  cmakeFlags = [
    # (cmakeBool "BUILD_API_TEST" false) # Missing source files # TODO: Unused
    (cmakeBool "BUILD_ONNXIFI" false) # Missing source files
    (cmakeFeature "ONNX_NAMESPACE" "onnx") # Should be the same as what we built Onnx with
  ];

  nativeBuildInputs = [
    cmake
    cuda_nvcc
    python3
    protobuf_21
  ];

  buildInputs = [
    cuda_cudart
    onnx_1_12
    protobuf_21
    tensorrt_8_5_2
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
