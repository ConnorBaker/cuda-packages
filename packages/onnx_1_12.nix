{
  abseil-cpp,
  backendStdenv,
  cmake,
  fetchFromGitHub,
  gtest,
  lib,
  protobuf_21,
  python3,
}:
let
  inherit (lib.strings) cmakeBool cmakeFeature;
in
backendStdenv.mkDerivation (finalAttrs: {
  strictDeps = true;

  pname = "onnx";
  # The version checked in for onnx-tensorrt version 8.5: https://github.com/onnx/onnx-tensorrt/tree/8.5-GA/third_party
  version = "1.12.0";

  src = fetchFromGitHub {
    owner = finalAttrs.pname;
    repo = finalAttrs.pname;
    rev = "refs/tags/v${finalAttrs.version}";
    hash = "sha256-3awGaKbzvZraGFJWoKIfHDh7qm6gWWfiO3bpGTcMLr0=";
  };

  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail \
        "include(googletest)" \
        "find_package(GTest REQUIRED)"
    substituteInPlace cmake/unittest.cmake \
      --replace-fail \
        "googletest_STATIC_LIBRARIES" \
        "GTEST_LIBRARIES" \
      --replace-fail \
        "googletest_INCLUDE_DIRS" \
        "GTEST_INCLUDE_DIRS" \
      --replace-fail \
        "googletest" \
        "GTest::gtest"
  '';

  nativeBuildInputs = [
    cmake
    protobuf_21
    python3
  ];

  buildInputs = [
    abseil-cpp
    protobuf_21
  ];

  cmakeFlags = [
    (cmakeBool "BUILD_ONNX_PYTHON" false)
    (cmakeBool "BUILD_SHARED_LIBS" true)
    (cmakeBool "ONNX_BUILD_BENCHMARKS" false)
    # (cmakeBool "ONNX_BUILD_SHARED_LIBS" true) # TODO: Not recognized
    (cmakeBool "ONNX_BUILD_TESTS" finalAttrs.doCheck)
    # (cmakeBool "ONNX_GEN_PB_TYPE_STUBS" false) # TODO: Not recognized
    (cmakeBool "ONNX_ML" false)
    (cmakeBool "ONNX_USE_PROTOBUF_SHARED_LIBS" true)
    (cmakeBool "ONNX_VERIFY_PROTO3" true)
    (cmakeFeature "ONNX_NAMESPACE" "onnx")
  ];

  doCheck = true;

  checkInputs = [
    gtest
  ];

  meta = with lib; {
    description = "Open Neural Network Exchange";
    homepage = "https://onnx.ai";
    license = licenses.asl20;
    maintainers = with maintainers; [ connorbaker ];
  };
})
