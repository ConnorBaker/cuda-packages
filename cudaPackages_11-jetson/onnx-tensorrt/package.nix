{
  backendStdenv,
  cuda_cudart,
  cuda_nvcc,
  fetchFromGitHub,
  lib,
  onnx,
  onnx-tensorrt, # For passthru.tests.gpu
  protobuf_21,
  pycuda,
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
    ;

  version = "8.5";
in
# Version must have only two components.
assert version == (majorMinor version);
buildPythonPackage {
  # Must opt-out of __structuredAttrs which is on by default in our stdenv, but currently incompatible with Python
  # packaging: https://github.com/NixOS/nixpkgs/pull/347194.
  __structuredAttrs = false;
  stdenv = backendStdenv;

  pname = "onnx-tensorrt";
  inherit version;

  src = fetchFromGitHub {
    owner = "onnx";
    repo = "onnx-tensorrt";
    rev = "refs/tags/release/${version}-GA";
    hash = "sha256-UPFHw4ode+RNog2c665u2wjNhjMn6Y3dl7wiw6HptlM=";
  };

  pyproject = true;

  build-system = [ setuptools ];

  nativeBuildInputs = [
    cmake
    cuda_nvcc
    protobuf_21
  ];

  # NOTE: Can't build static libraries on this version for Jetson due to attempts to link against static firmware
  # binaries.
  patches = [ ./onnx-8.5-only-dynamic-lib.patch ];

  postPatch =
    # The python library `onnx_tensorrt` references itself during the install phase. Unfortunately, it tries to access
    # the GPU when it is imported, which causes a segfault.
    # Patch `setup.py` to not rely on `onnx_tensorrt`.
    # TODO: Should use actual version given in `__init__.py` instead of hardcoding.
    ''
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
    cuda_cudart
    protobuf_21
    tensorrt
  ];

  propagatedBuildInputs = [ (getLib cuda_cudart) ];

  postInstall =
    # After the python install is complete, re-enter the build directory to  install the C++ components.
    ''
      pushd "''${cmakeBuildDir:?}"
      echo "Running CMake install for C++ components"
      make install -j ''${NIX_BUILD_CORES:?}
      popd
    ''
    # Install the header files to the include directory.
    + ''
      mkdir -p "$out/include/onnx"
      install -Dm644 *.h *.hpp "$out/include/onnx"
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
              export HOME="$(mktemp --directory)"
              trap 'rm -rf -- "''${HOME@Q}"' EXIT
            ''
            # Run the tests.
            + ''
              install -Dm755 "${onnx-tensorrt.src}/onnx_backend_test.py" .
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
