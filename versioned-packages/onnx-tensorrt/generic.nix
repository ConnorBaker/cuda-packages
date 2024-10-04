{
  backendStdenv,
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cudaMajorMinorVersion,
  fetchFromGitHub,
  lib,
  python3,
  # Package overrides
  version,
  protobuf,
  onnx_1_14,
  onnx_1_16,
  protobuf_21,
  tensorrt_8_5,
  tensorrt_10_4,
}:
let
  inherit (lib.lists) optionals;
  inherit (lib.strings) cmakeBool cmakeFeature optionalString;
  inherit (lib.versions) majorMinor;

  hash =
    {
      "8.5" = "sha256-UPFHw4ode+RNog2c665u2wjNhjMn6Y3dl7wiw6HptlM=";
      "10.4" = "sha256-ZHWIwPy/iQS6iKAxVL9kKM+KbfzvktFrCElie4Aj8mg=";
    }
    .${version};

  effectiveOnnx =
    {
      # TODO(@connorbaker): NVIDIA builds against Onnx 1.12 for 8.5., but the corresponding release of onnxruntime uses Onnx 1.14.
      "8.5" = onnx_1_14;
      "10.4" = onnx_1_16;
    }
    .${version};

  effectiveProtobuf =
    {
      "8.5" = protobuf_21;
      "10.4" = protobuf;
    }
    .${version};

  effectiveTensorRT =
    {
      "8.5" = tensorrt_8_5;
      "10.4" = tensorrt_10_4;
    }
    .${version};
in
# Version must have only two components.
assert version == (majorMinor version);
backendStdenv.mkDerivation (finalAttrs: {
  strictDeps = true;

  name = "cuda${cudaMajorMinorVersion}-${finalAttrs.pname}-${version}";
  pname = "onnx-tensorrt";
  inherit version;

  src = fetchFromGitHub {
    owner = "onnx";
    repo = "onnx-tensorrt";
    rev = "refs/tags/release/${version}-GA";
    inherit hash;
  };

  # NOTE: Can't build static libraries on this version for Jetson due to attempts to link against static firmware
  # binaries.
  patches = optionals (version == "8.5") [
    ./onnx-8.5-only-dynamic-lib.patch
  ];

  # Ensure Onnx is found by CMake rather than using the vendored version.
  # https://github.com/onnx/onnx-tensorrt/blob/3775e499322eee17c837e27bff6d07af4261767a/CMakeLists.txt#L90
  postPatch = optionalString (version == "10.4") ''
    substituteInPlace CMakeLists.txt \
      --replace-fail \
        "add_subdirectory(third_party/onnx EXCLUDE_FROM_ALL)" \
        "find_package(ONNX REQUIRED)"
  '';

  cmakeFlags =
    [
      (cmakeBool "BUILD_ONNXIFI" false) # Missing source files
      (cmakeFeature "ONNX_NAMESPACE" "onnx") # Should be the same as what we built Onnx with
    ]
    ++ optionals (version == "10.4") [
      (cmakeBool "BUILD_API_TEST" false) # Missing source files
    ];

  nativeBuildInputs = [
    cmake
    cuda_nvcc
    python3
    effectiveProtobuf
  ];

  buildInputs = [
    cuda_cudart
    effectiveOnnx
    effectiveProtobuf
    effectiveTensorRT
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
