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
  tensorrt-python_10_4,
}:
let
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe;
  inherit (lib.strings) cmakeBool cmakeFeature optionalString;
  inherit (lib.versions) majorMinor;

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
    pycuda
    wheel
    ;

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

  effectivePythonProtobuf =
    {
      "8.5" = protobuf4;
      "10.4" = protobuf5;
    }
    .${version};

  python3Env = python3.withPackages (ps: with ps; [ setuptools ]);
in
# Version must have only two components.
assert version == (majorMinor version);
buildPythonPackage {
  strictDeps = true;

  name = "cuda${cudaMajorMinorVersion}-onnx-tensorrt-${version}";
  pname = "onnx-tensorrt";
  inherit version;

  src = fetchFromGitHub {
    owner = "onnx";
    repo = "onnx-tensorrt";
    rev = "refs/tags/release/${version}-GA";
    inherit hash;
  };

  pyproject = true;

  build-system = [ setuptools ];

  dependencies = [
    effectiveOnnx
    # tensorrt-python_10_4
    pycuda
  ];

  # NOTE: Can't build static libraries on this version for Jetson due to attempts to link against static firmware
  # binaries.
  patches = optionals (version == "8.5") [ ./onnx-8.5-only-dynamic-lib.patch ];

  postPatch =
    # Ensure Onnx is found by CMake rather than using the vendored version.
    # https://github.com/onnx/onnx-tensorrt/blob/3775e499322eee17c837e27bff6d07af4261767a/CMakeLists.txt#L90
    optionalString (version == "10.4") ''
      substituteInPlace CMakeLists.txt \
        --replace-fail \
          "add_subdirectory(third_party/onnx EXCLUDE_FROM_ALL)" \
          "find_package(ONNX REQUIRED)"
    ''
    # The python library `onnx_tensorrt` references itself during the install phase. Unfortunately, it tries to access
    # the GPU when it is imported, which causes a segfault.
    # Patch `setup.py` to not rely on `onnx_tensorrt`.
    # TODO: Should use actual version given in `__init__.py` instead of hardcoding.
    + ''
      substituteInPlace setup.py \
        --replace-fail \
          "import onnx_tensorrt" \
          "" \
        --replace-fail \
          "onnx_tensorrt.__version__" \
          "${version}"
    '';

  nativeBuildInputs = [
    # cmake
    cuda_nvcc
    effectiveProtobuf
  ];

  buildInputs = [
    cuda_cudart
    effectiveProtobuf
    effectiveTensorRT
  ];

  # cmakeFlags =
  #   [
  #     (cmakeBool "BUILD_ONNXIFI" false) # Missing source files
  #     (cmakeFeature "ONNX_NAMESPACE" "onnx") # Should be the same as what we built Onnx with
  #   ]
  #   ++ optionals (version == "10.4") [
  #     (cmakeBool "BUILD_API_TEST" false) # Missing source files
  #   ];

  # # Re-export the `cmakeFlags` environment variable as CMAKE_ARGS so setup.py will pick them up, then exit
  # # the build directory for the python build.
  # postConfigure = ''
  #   # export CMAKE_ARGS="''${cmakeFlags[*]}"
  #   cd ..
  # '';

  # # After the python install is complete, re-enter the build directory to  install the C++ components.
  # postInstall = ''
  #   pushd "''${cmakeBuildDir:?}"
  #   echo "Running CMake install for C++ components"
  #   make install
  #   popd
  # '';

  doCheck = true;

  meta = with lib; {
    description = "TensorRT backend for Onnx";
    homepage = "https://github.com/onnx/onnx-tensorrt";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = with maintainers; [ connorbaker ] ++ teams.cuda.members;
  };
}
