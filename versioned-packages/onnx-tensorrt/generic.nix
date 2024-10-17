{
  backendStdenv,
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cudaMajorMinorVersion,
  fetchFromGitHub,
  lib,
  onnx,
  python3,
  # Package overrides
  version,
  hash,
  protobuf,
  tensorrt,
}:
let
  inherit (lib.lists) optionals;
  inherit (lib.strings) cmakeBool cmakeFeature optionalString;
  inherit (lib.versions) majorMinor;
in
# Version must have only two components.
assert version == (majorMinor version);
backendStdenv.mkDerivation (finalAttrs: {
  strictDeps = true;

  name = "cuda${cudaMajorMinorVersion}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "onnx-tensorrt";
  inherit version;

  src = fetchFromGitHub {
    owner = "onnx";
    repo = "onnx-tensorrt";
    rev = "refs/tags/release/${finalAttrs.version}-GA";
    inherit hash;
  };

  # NOTE: Can't build static libraries on this version for Jetson due to attempts to link against static firmware
  # binaries.
  patches = optionals (finalAttrs.version == "8.5") [
    ./onnx-8.5-only-dynamic-lib.patch
  ];

  # Ensure Onnx is found by CMake rather than using the vendored version.
  # https://github.com/onnx/onnx-tensorrt/blob/3775e499322eee17c837e27bff6d07af4261767a/CMakeLists.txt#L90
  postPatch = optionalString (finalAttrs.version == "10.4") ''
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
    ++ optionals (finalAttrs.version == "10.4") [
      (cmakeBool "BUILD_API_TEST" false) # Missing source files
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
    tensorrt
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
