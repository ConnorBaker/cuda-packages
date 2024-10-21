{
  abseil-cpp,
  backendStdenv,
  fetchFromGitHub,
  gtest,
  lib,
  patchelf,
  protobuf_21,
  python3,
}:
let
  inherit (builtins) storeDir;
  inherit (lib.meta) getExe;
  inherit (lib.strings) cmakeBool cmakeFeature;
  inherit (python3.pkgs)
    buildPythonPackage
    cmake
    google-re2
    nbval
    numpy
    parameterized
    pillow
    protobuf4
    pybind11
    pytestCheckHook
    setuptools
    tabulate
    typing-extensions
    ;

in
buildPythonPackage {
  strictDeps = true;
  stdenv = backendStdenv;

  pname = "onnx";
  version = "1.14.1";

  src = fetchFromGitHub {
    owner = "onnx";
    repo = "onnx";
    rev = "refs/tags/v1.14.1";
    hash = "sha256-ZVSdk6LeAiZpQrrzLxphMbc1b3rNUMpcxcXPP8s/5tE=";
  };
  pyproject = true;

  build-system = [
    cmake
    protobuf4
    setuptools
  ];

  nativeBuildInputs = [
    abseil-cpp
    protobuf_21
    pybind11
  ];

  postPatch =
    # Patch script template
    ''
      chmod +x tools/protoc-gen-mypy.sh.in
      patchShebangs tools/protoc-gen-mypy.sh.in
    ''
    # Patch setup and CMake
    + ''
      substituteInPlace setup.py \
        --replace-fail \
        'setup_requires.append("pytest-runner")' \
        ""
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

  dependencies = [
    abseil-cpp
    numpy
    protobuf4
  ];

  buildInputs = [
    abseil-cpp
    protobuf_21
  ];

  # Declared in setup.py
  cmakeBuildDir = ".setuptools-cmake-build";

  cmakeFlags = [
    (cmakeBool "BUILD_ONNX_PYTHON" true)
    (cmakeBool "BUILD_SHARED_LIBS" true)
    (cmakeBool "ONNX_BUILD_BENCHMARKS" false)
    (cmakeBool "ONNX_BUILD_TESTS" true)
    (cmakeBool "ONNX_ML" false) # NOTE: If this is `true`, onnx-tensorrt fails to build due to missing protobuf files.
    (cmakeBool "ONNX_USE_PROTOBUF_SHARED_LIBS" true)
    (cmakeBool "ONNX_VERIFY_PROTO3" true)
    (cmakeFeature "ONNX_NAMESPACE" "onnx")
  ];

  # Re-export the `cmakeFlags` environment variable as CMAKE_ARGS so setup.py will pick them up, then exit
  # the build directory for the python build.
  # TODO: How does bash handle accessing `cmakeFlags` as an array when __structuredAttrs is not set?
  postConfigure = ''
    export CMAKE_ARGS="''${cmakeFlags[@]}"
    cd ..
  '';

  # After the python install is complete, re-enter the build directory to  install the C++ components.
  postInstall = ''
    pushd "''${cmakeBuildDir:?}"
    echo "Running CMake install for C++ components"
    make install -j ''${NIX_BUILD_CORES:?}
    popd
  '';

  doCheck = true;

  nativeCheckInputs = [
    google-re2
    nbval
    parameterized
    pillow
    pytestCheckHook
    tabulate
    typing-extensions
  ];

  checkInputs = [ gtest ];

  disabledTests = [
    # AssertionError: Output 0 of test 0 in folder '/nix/store/ksxnk2b0l69mbydgla...
    # "onnx/test/reference_evaluator_backend_test.py::TestOnnxBackEndWithReferenceEvaluator::test__pytorch_converted_Conv2d_depthwise_padded"
    "test__pytorch_converted_Conv2d_depthwise_padded"
    # AssertionError: Output 0 of test 0 in folder '/nix/store/ksxnk2b0l69mbydgla...
    # "onnx/test/reference_evaluator_backend_test.py::TestOnnxBackEndWithReferenceEvaluator::test__pytorch_converted_Conv2d_dilated"
    "test__pytorch_converted_Conv2d_dilated"
    # AssertionError: Mismatch in test 'test_Conv2d_depthwise_padded'
    # "onnx/test/reference_evaluator_backend_test.py::TestOnnxBackEndWithReferenceEvaluator::test_xor_bcast4v4d"
    "test_xor_bcast4v4d"
  ];

  preCheck =
    ''
      echo "Running C++ tests"
      "''${cmakeBuildDir:?}/onnx_gtests"
    ''
    # Fixups for pytest
    + ''
      export HOME=$(mktemp -d)
    ''
    # Detecting source dir as a python package confuses pytest and causes import errors
    + ''
      mv onnx/__init__.py onnx/__init__.py.hidden
    '';

  pythonImportsCheck = [ "onnx" ];

  # Some libraries maintain a reference to /build/source, so we need to remove the reference.
  preFixup = ''
    find "$out" \
      -type f \
      -name '*.so' \
      -exec "${getExe patchelf}" \
        --remove-rpath \
        --shrink-rpath \
        --allowed-rpath-prefixes "${storeDir}" \
        '{}' \;
  '';

  meta = with lib; {
    description = "Open Neural Network Exchange";
    homepage = "https://onnx.ai";
    license = licenses.asl20;
    maintainers = with maintainers; [ connorbaker ];
  };
}
