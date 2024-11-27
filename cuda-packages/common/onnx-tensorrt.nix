{
  backendStdenv,
  cuda_cudart,
  cuda_nvcc,
  fetchFromGitHub,
  lib,
  onnx,
  protobuf_25,
  pycuda,
  python3,
  tensorrt-python,
  tensorrt-oss,
}:
let
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets) getLib;
  inherit (lib.strings) cmakeBool cmakeFeature;
  inherit (lib.versions) majorMinor;

  inherit (python3.pkgs)
    buildPythonPackage
    cmake # Yes, we need cmake from python3Packages in order for the build to work.
    setuptools
    ;

  finalAttrs = {
    # Must opt-out of __structuredAttrs which is on by default in our stdenv, but currently incompatible with Python
    # packaging: https://github.com/NixOS/nixpkgs/pull/347194.
    __structuredAttrs = false;
    stdenv = backendStdenv;

    pname = "onnx-tensorrt";
    version = "10.6";

    src = fetchFromGitHub {
      owner = "onnx";
      repo = "onnx-tensorrt";
      rev = "refs/tags/release/${finalAttrs.version}-GA";
      hash = "sha256-mhOzSeysMIC5KmHupuOz1sZsaP/Zv81ucx193njkU20=";
    };

    outputs = [
      "out"
      "static"
      "test_script"
    ];

    pyproject = true;

    # NOTE: The project, as of 10.6, does not use ninja.
    build-system = [
      cmake
      setuptools
    ];

    nativeBuildInputs = [
      cuda_nvcc
      protobuf_25
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
            "${finalAttrs.version}"
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

    # After CMake configuration finishes, return to the source directory to install the C++ components.
    postConfigure = ''
      cd "$NIX_BUILD_TOP/$sourceRoot"
    '';

    dependencies = [
      onnx
      pycuda
      tensorrt-python
    ];

    buildInputs = [
      cuda_cudart
      protobuf_25
      tensorrt-oss
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
      ''
      # Move static libraries to the static directory.
      + ''
        moveToOutput lib/libnvonnxparser_static.a "$static"
      ''
      # Copy over the file we'll use for testing.
      + ''
        mkdir -p "$test_script"
        install -Dm755 "$NIX_BUILD_TOP/$sourceRoot/onnx_backend_test.py" "$test_script/onnx_backend_test.py"
      ''
      # Patch our test file to skip tests that are known to fail.
      # These two tests fail with out of memory errors on a 4090.
      + ''
        substituteInPlace "$test_script/onnx_backend_test.py" \
          --replace-fail \
            "backend_test.include(r'.*test_vgg19.*')" \
            "# backend_test.include(r'.*test_vgg19.*')" \
          --replace-fail \
            "backend_test.include(r'.*test_zfnet512.*')" \
            "# backend_test.include(r'.*test_zfnet512.*')"
      '';

    doCheck = true;

    meta = with lib; {
      description = "TensorRT backend for Onnx";
      homepage = "https://github.com/onnx/onnx-tensorrt";
      license = licenses.asl20;
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      maintainers = (with maintainers; [ connorbaker ]) ++ teams.cuda.members;
    };
  };
in
assert assertMsg (
  finalAttrs.version == majorMinor finalAttrs.version
) "Version must have only two components";
assert assertMsg (
  finalAttrs.version == majorMinor tensorrt-oss.version
) "Version must match tensorrt-oss";
buildPythonPackage finalAttrs
