{
  abseil-cpp,
  backendStdenv,
  cmake,
  fetchFromGitHub,
  gtest,
  lib,
  protobuf,
  python3,
}:
let
  inherit (lib.strings) cmakeBool cmakeFeature;
in
backendStdenv.mkDerivation (finalAttrs: {
  strictDeps = true;

  pname = "onnx";
  version = "1.16.2";

  src = fetchFromGitHub {
    owner = finalAttrs.pname;
    repo = finalAttrs.pname;
    rev = "refs/tags/v${finalAttrs.version}";
    hash = "sha256-JmxnsHRrzj2QzPz3Yndw0MmgZJ8MDYxHjuQ7PQkQsDg=";
  };

  nativeBuildInputs = [
    cmake
    protobuf
    python3
  ];

  buildInputs = [
    abseil-cpp
    protobuf
  ];

  cmakeFlags = [
    (cmakeBool "BUILD_ONNX_PYTHON" false)
    (cmakeBool "BUILD_SHARED_LIBS" true)
    (cmakeBool "ONNX_BUILD_BENCHMARKS" false)
    (cmakeBool "ONNX_BUILD_SHARED_LIBS" true)
    (cmakeBool "ONNX_BUILD_TESTS" finalAttrs.doCheck)
    (cmakeBool "ONNX_GEN_PB_TYPE_STUBS" false)
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
