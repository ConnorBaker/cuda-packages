{
  abseil-cpp,
  autoPatchelfHook,
  fetchFromGitHub,
  fetchpatch2,
  gtest,
  lib,
  patchelf,
  protobuf_21,
  protobuf, # TODO: This would be versioned, but upstream does not version the default.
  python3,
  srcOnly,
  # Package overrides
  version,
}:
let
  inherit (builtins) storeDir;
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe;
  inherit (lib.strings) cmakeBool cmakeFeature optionalString;
  inherit (python3.pkgs)
    buildPythonPackage
    cmake
    google-re2
    nbval
    numpy
    parameterized
    pillow
    protobuf4
    protobuf5
    pybind11
    pytestCheckHook
    setuptools
    tabulate
    typing-extensions
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
      };
    in
    if version == "1.14.1" then patchedOnnxSource else onnxSource;

  effectiveProtobuf =
    {
      "1.14.1" = protobuf_21;
      "1.16.2" = protobuf;
    }
    .${version};

  effectivePythonProtobuf =
    {
      "1.14.1" = protobuf4;
      "1.16.2" = protobuf5;
    }
    .${version};
in
buildPythonPackage {
  strictDeps = true;

  pname = "onnx";
  inherit version;

  inherit src;
  pyproject = true;

  build-system = [
    cmake
    effectivePythonProtobuf
    setuptools
  ];

  dependencies = [
    abseil-cpp
    effectivePythonProtobuf
    numpy
  ];

  nativeBuildInputs = [
    abseil-cpp
    autoPatchelfHook
    effectiveProtobuf
    pybind11
  ];

  postPatch = ''
    chmod +x tools/protoc-gen-mypy.sh.in
    patchShebangs tools/protoc-gen-mypy.sh.in
  '';

  buildInputs = [
    abseil-cpp
    effectiveProtobuf
  ];

  # Declared in setup.py
  cmakeBuildDir = ".setuptools-cmake-build";

  cmakeFlags =
    [
      (cmakeBool "BUILD_ONNX_PYTHON" true)
      (cmakeBool "BUILD_SHARED_LIBS" true)
      (cmakeBool "ONNX_BUILD_BENCHMARKS" false)
      (cmakeBool "ONNX_BUILD_TESTS" true)
      (cmakeBool "ONNX_ML" false) # NOTE: If this is `true`, onnx-tensorrt fails to build due to missing protobuf files.
      (cmakeBool "ONNX_USE_PROTOBUF_SHARED_LIBS" true)
      (cmakeBool "ONNX_VERIFY_PROTO3" true)
      (cmakeFeature "ONNX_NAMESPACE" "onnx")
    ]
    ++ optionals (version == "1.16.2") [
      (cmakeBool "ONNX_BUILD_SHARED_LIBS" true)
      (cmakeBool "ONNX_GEN_PB_TYPE_STUBS" true)
    ];

  # Re-export the `cmakeFlags` environment variable as CMAKE_ARGS so setup.py will pick them up, then exit
  # the build directory for the python build.
  postConfigure = ''
    export CMAKE_ARGS="''${cmakeFlags[*]}"
    cd ..
  '';

  # After the python install is complete, re-enter the build directory to  install the C++ components.
  postInstall = ''
    pushd "''${cmakeBuildDir:?}"
    echo "Running CMake install for C++ components"
    make install
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
  ] ++ optionals (version == "1.14.1") [ typing-extensions ];

  checkInputs = [ gtest ];

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
  # We use the autoPatchelfHook as a safeguard to ensure that we don't miss any dependencies.
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
