{
  buildPythonPackage,
  cmake, # Yes, we need cmake from python3Packages in order for the build to work.
  config,
  cudaPackages,
  cudaSupport ? config.cudaSupport,
  fetchFromGitHub,
  lib,
  onnx,
  pycuda,
  setuptools,
  tensorrt-python,
}:
let
  inherit (cudaPackages)
    cuda_cudart
    cuda_nvcc
    tensorrt
    ;
  inherit (lib) licenses maintainers teams;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets) getLib getOutput;
  inherit (lib.strings) cmakeBool cmakeFeature;
  inherit (lib.versions) majorMinor;
  inherit (onnx.passthru) cppProtobuf;

  finalAttrs = {
    # Must opt-out of __structuredAttrs which is set to true by default by cudaPackages.callPackage, but currently
    # incompatible with Python packaging: https://github.com/NixOS/nixpkgs/pull/347194.
    __structuredAttrs = false;

    pname = "onnx-tensorrt";
    version = majorMinor tensorrt.version;

    src = fetchFromGitHub {
      owner = "onnx";
      repo = "onnx-tensorrt";
      tag = "release/${finalAttrs.version}-GA";
      hash =
        {
          "10.7" = "sha256-1Y5jELqVkRkjeiEbF7GrPqAGZMu7U8JgmM3ZQbsG304=";
          "10.8" = "sha256-wIi1+V8ZVs0tZxtfG0kxTZcB03IKMO1KJuWypaAFi3g=";
        }
        .${finalAttrs.version};
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
      cppProtobuf
      cuda_nvcc
    ];

    postPatch =
      # Ensure Onnx is found by CMake rather than using the vendored version.
      # https://github.com/onnx/onnx-tensorrt/blob/3775e499322eee17c837e27bff6d07af4261767a/CMakeLists.txt#L90
      ''
        nixLog "patching CMakeLists.txt to use Nixpkgs' Onnx"
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
        nixLog "patching setup.py to remove onnx_tensorrt import"
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
        nixLog "patching backend.py to load libcudart.so from the correct path"
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

    postConfigure = ''
      nixLog "returning to sourceRoot to install Python components"
      cd "$NIX_BUILD_TOP/$sourceRoot"
    '';

    dependencies = [
      onnx
      pycuda
      tensorrt-python
    ];

    buildInputs = [
      (getOutput "include" cuda_nvcc) # for crt/host_defines.h
      cppProtobuf
      cuda_cudart
      tensorrt
    ];

    propagatedBuildInputs = [ (getLib cuda_cudart) ];

    postInstall =
      # After the python install is complete, re-enter the build directory to  install the C++ components.
      ''
        nixLog "returning to ''${cmakeBuildDir:?} directory to install C++ components"
        pushd "''${cmakeBuildDir:?}"
        nixLog "installing C++ components"
        make install -j ''${NIX_BUILD_CORES:?}
        popd
      ''
      # Install the header files to the include directory.
      + ''
        nixLog "installing header files"
        mkdir -p "$out/include/onnx"
        install -Dm644 *.h *.hpp "$out/include/onnx"
      ''
      # Move static libraries to the static directory.
      + ''
        moveToOutput lib/libnvonnxparser_static.a "$static"
      ''
      # Copy over the file we'll use for testing.
      + ''
        nixLog "installing test script"
        mkdir -p "$test_script"
        install -Dm755 "$NIX_BUILD_TOP/$sourceRoot/onnx_backend_test.py" "$test_script/onnx_backend_test.py"
      ''
      # Patch our test file to skip tests that are known to fail.
      # These two tests fail with out of memory errors on a 4090.
      + ''
        nixLog "patching test script to skip known failing tests"
        substituteInPlace "$test_script/onnx_backend_test.py" \
          --replace-fail \
            "backend_test.include(r'.*test_vgg19.*')" \
            "# backend_test.include(r'.*test_vgg19.*')" \
          --replace-fail \
            "backend_test.include(r'.*test_zfnet512.*')" \
            "# backend_test.include(r'.*test_zfnet512.*')"
      '';

    doCheck = true;

    meta = {
      broken = !cudaSupport;
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
assert assertMsg (finalAttrs.version == majorMinor tensorrt.version) "Version must match tensorrt";
buildPythonPackage finalAttrs
