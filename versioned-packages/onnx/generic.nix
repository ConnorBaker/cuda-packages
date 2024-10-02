{
  abseil-cpp,
  backendStdenv,
  cmake,
  fetchFromGitHub,
  gtest,
  lib,
  python3,
  # Package overrides
  version,
  hash,
  protobuf,
}:
let
  inherit (lib.lists) optionals;
  inherit (lib.strings)
    cmakeBool
    cmakeFeature
    optionalString
    ;
  inherit (lib.versions) majorMinor;
in
backendStdenv.mkDerivation (finalAttrs: {
  strictDeps = true;

  pname = "onnx";
  inherit version;

  src = fetchFromGitHub {
    owner = "onnx";
    repo = "onnx";
    rev = "refs/tags/v${finalAttrs.version}";
    inherit hash;
  };

  nativeBuildInputs = [
    cmake
    protobuf
    python3
  ];

  postPatch = optionalString (majorMinor finalAttrs.version == "1.12") ''
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

  buildInputs = [
    abseil-cpp
    protobuf
  ];

  cmakeFlags =
    [
      (cmakeBool "BUILD_ONNX_PYTHON" false)
      (cmakeBool "BUILD_SHARED_LIBS" true)
      (cmakeBool "ONNX_BUILD_BENCHMARKS" false)
      (cmakeBool "ONNX_BUILD_TESTS" finalAttrs.doCheck)
      (cmakeBool "ONNX_ML" false)
      (cmakeBool "ONNX_USE_PROTOBUF_SHARED_LIBS" true)
      (cmakeBool "ONNX_VERIFY_PROTO3" true)
      (cmakeFeature "ONNX_NAMESPACE" "onnx")
    ]
    ++ optionals (majorMinor finalAttrs.version == "1.16") [
      (cmakeBool "ONNX_BUILD_SHARED_LIBS" true)
      (cmakeBool "ONNX_GEN_PB_TYPE_STUBS" false)
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
