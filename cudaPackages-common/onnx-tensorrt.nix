{
  backendStdenv,
  cuda_cudart,
  cuda_nvcc,
  cudaMajorMinorVersion,
  fetchFromGitHub,
  lib,
  onnx,
  onnx-tensorrt, # For passthru.tests.gpu
  protobuf,
  python3,
  tensorrt-python,
  tensorrt,
  runCommand,
}:
let
  inherit (lib.attrsets) getLib;
  inherit (lib.strings) cmakeBool cmakeFeature;
  inherit (lib.versions) majorMinor;

  inherit (python3.pkgs)
    buildPythonPackage
    cmake # Yes, we need cmake from python3Packages in order for the build to work.
    setuptools
    pycuda
    ;

  version = "10.4";
in
# Version must have only two components.
assert version == (majorMinor version);
buildPythonPackage {
  strictDeps = true;
  stdenv = backendStdenv;

  name = "cuda${cudaMajorMinorVersion}-onnx-tensorrt-${version}";
  pname = "onnx-tensorrt";
  inherit version;

  src = fetchFromGitHub {
    owner = "onnx";
    repo = "onnx-tensorrt";
    rev = "refs/tags/release/${version}-GA";
    hash = "sha256-ZHWIwPy/iQS6iKAxVL9kKM+KbfzvktFrCElie4Aj8mg=";
  };

  pyproject = true;

  build-system = [ setuptools ];

  nativeBuildInputs = [
    cmake
    cuda_nvcc
    protobuf
  ];

  postPatch =
    # Ensure Onnx is found by CMake rather than using the vendored version.
    # https://github.com/onnx/onnx-tensorrt/blob/3775e499322eee17c837e27bff6d07af4261767a/CMakeLists.txt#L90
    ''
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
    ''
    # Patch onnx_tensorrt/backend.py to load the path to libcudart.so directly so the end-user doesn't need to manually
    # add it to LD_LIBRARY_PATH.
    + ''
      substituteInPlace onnx_tensorrt/backend.py \
        --replace-fail \
          "LoadLibrary('libcudart.so')" \
          "LoadLibrary('${getLib cuda_cudart}/lib/libcudart.so')"
    '';

  cmakeFlags = [
    (cmakeBool "BUILD_API_TEST" false) # Missing source files
    (cmakeBool "BUILD_ONNXIFI" false) # Missing source files
    (cmakeFeature "ONNX_NAMESPACE" "onnx") # Should be the same as what we built Onnx with
  ];

  # After CMake configuration finishes, exit the build directory for the python build.
  postConfigure = ''
    cd ..
  '';

  dependencies = [
    onnx
    pycuda
    tensorrt-python
  ];

  buildInputs = [
    protobuf
    tensorrt
  ];

  propagatedBuildInputs = [ (getLib cuda_cudart) ];

  postInstall =
    # After the python install is complete, re-enter the build directory to  install the C++ components.
    ''
      pushd "''${cmakeBuildDir:?}"
      echo "Running CMake install for C++ components"
      make install
      popd
    ''
    # Install the header files to the include directory.
    + ''
      mkdir -p "$out/include"
      install -Dm644 *.h "$out/include"
      install -Dm644 *.hpp "$out/include"
    '';

  doCheck = true;

  passthru.tests =
    let
      runOnnxTests =
        { fast }:
        runCommand "onnx-tensorrt-gpu-tests-${if fast then "short" else "long"}"
          {
            strictDeps = true;
            requiredSystemFeatures = [ "cuda" ];
            nativeBuildInputs = [
              # (getLib cuda_cudart)
              (python3.withPackages (ps: [
                onnx-tensorrt
                ps.pytest
              ]))
            ];
          }
          (
            # Make a temporary directory for the tests and error out if anything fails.
            ''
              set -e
              export HOME="$(mktemp -d)"
            ''
            # Patch our test file to skip tests that are known to fail.
            # These two tests fail with out of memory errors on a 4090.
            + ''
              cp "${onnx-tensorrt.src}/onnx_backend_test.py" .
              substituteInPlace onnx_backend_test.py \
                --replace-fail \
                  "backend_test.include(r'.*test_vgg19.*')" \
                  "# backend_test.include(r'.*test_vgg19.*')" \
                --replace-fail \
                  "backend_test.include(r'.*test_zfnet512.*')" \
                  "# backend_test.include(r'.*test_zfnet512.*')"
            ''
            # Run the tests.
            + ''
              python3 onnx_backend_test.py \
                --verbose \
                ${if fast then "OnnxBackendRealModelTest" else ""}
            ''
            # If we make it here, make an empty output and delete the temporary directory.
            + ''
              touch $out
              rm -rf "$HOME"
            ''
          );
    in
    {
      # NOTE: gpuShort shows
      # Ran 18 tests in 210.529s
      # on a 4090.
      gpuShort = runOnnxTests { fast = true; };
      gpuLong = runOnnxTests { fast = false; };
    };

  meta = with lib; {
    description = "TensorRT backend for Onnx";
    homepage = "https://github.com/onnx/onnx-tensorrt";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = with maintainers; [ connorbaker ] ++ teams.cuda.members;
  };
}
