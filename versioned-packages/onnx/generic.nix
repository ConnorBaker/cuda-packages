{
  abseil-cpp,
  backendStdenv,
  cmake,
  fetchFromGitHub,
  gtest,
  lib,
  python3,
  fetchpatch2,
  srcOnly,
  # Package overrides
  version,
  protobuf, # TODO: This would be versioned, but upstream does not version the default.
  protobuf_21,
}:
let
  inherit (lib.lists) optionals;
  inherit (lib.strings)
    cmakeBool
    cmakeFeature
    optionalString
    ;

  hash =
    {
      "1.14.1" = "sha256-ZVSdk6LeAiZpQrrzLxphMbc1b3rNUMpcxcXPP8s/5tE=";
      "1.16.2" = "sha256-JmxnsHRrzj2QzPz3Yndw0MmgZJ8MDYxHjuQ7PQkQsDg=";
    }
    .${version};

  src =
    let
      onnxSource = fetchFromGitHub {
        owner = "onnx";
        repo = "onnx";
        rev = "refs/tags/v${version}";
        inherit hash;
      };
      patchedOnnxSource = srcOnly {
        strictDeps = true;
        name = "onnx-source-${version}-patched";
        src = onnxSource;
        patches = optionals (version == "1.16.2") [
          (fetchpatch2 {
            name = "onnx.patch";
            url = "https://raw.githubusercontent.com/microsoft/onnxruntime/refs/tags/v1.19.2/cmake/patches/onnx/onnx.patch";
            hash = "sha256-TKQXuPY55sJeAndOiauxK4nYd0VaXabtys8W71i+hKM=";
          })
        ];

        postPatch = optionalString (version == "1.14.1") ''
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
      };
    in
    if version == "1.14.1" then patchedOnnxSource else onnxSource;

  effectiveProtobuf =
    {
      "1.14.1" = protobuf_21;
      "1.16.2" = protobuf;
    }
    .${version};
in
backendStdenv.mkDerivation (finalAttrs: {
  strictDeps = true;

  pname = "onnx";
  inherit version;

  inherit src;

  nativeBuildInputs = [
    cmake
    effectiveProtobuf
    python3
  ];

  buildInputs = [
    abseil-cpp
    effectiveProtobuf
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
    ++ optionals (version == "1.16.2") [
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
