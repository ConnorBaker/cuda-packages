{
  abseil-cpp,
  backendStdenv,
  fetchFromGitHub,
  gtest,
  lib,
  patchelf,
  protobuf,
  python3,
}:
let
  inherit (builtins) storeDir;
  inherit (lib.attrsets) attrNames;
  inherit (lib.lists) map;
  inherit (lib.meta) getExe;
  inherit (lib.strings) cmakeFeature;
  inherit (python3.pkgs)
    buildPythonPackage
    cmake
    google-re2
    nbval
    numpy
    parameterized
    pillow
    protobuf5
    pybind11
    pytestCheckHook
    setuptools
    tabulate
    ;

  finalAttrs = {
    # Must opt-out of __structuredAttrs which is on by default in our stdenv, but currently incompatible with Python
    # packaging: https://github.com/NixOS/nixpkgs/pull/347194.
    __structuredAttrs = false;
    stdenv = backendStdenv;

    pname = "onnx";

    version = "1.17.0";

    src = fetchFromGitHub {
      owner = "onnx";
      repo = "onnx";
      rev = "refs/tags/v${finalAttrs.version}";
      hash = "sha256-9oORW0YlQ6SphqfbjcYb0dTlHc+1gzy9quH/Lj6By8Q=";
    };

    pyproject = true;

    # NOTE: The project can not take advantage of ninja (as of 1.17.0).
    build-system = [
      cmake
      protobuf5
      setuptools
    ];

    nativeBuildInputs = [
      abseil-cpp
      protobuf
      pybind11
    ];

    # Patch script template
    postPatch = ''
      chmod +x tools/protoc-gen-mypy.sh.in
      patchShebangs tools/protoc-gen-mypy.sh.in
    '';

    buildInputs = [
      abseil-cpp
      protobuf
    ];

    dependencies = [
      abseil-cpp
      numpy
      protobuf5
    ];

    # Declared in setup.py
    cmakeBuildDir = ".setuptools-cmake-build";

    # Python setup.py just takes stuff from the environment.
    env = {
      BUILD_SHARED_LIBS = "1";
      ONNX_BUILD_BENCHMARKS = "0";
      ONNX_BUILD_PYTHON = "1";
      ONNX_BUILD_SHARED_LIBS = "1";
      ONNX_BUILD_TESTS = if finalAttrs.doCheck then "1" else "0";
      ONNX_GEN_PB_TYPE_STUBS = "1";
      ONNX_ML = "1"; # NOTE: If this is `true`, onnx-tensorrt fails to build due to missing protobuf files.
      ONNX_NAMESPACE = "onnx";
      ONNX_USE_PROTOBUF_SHARED_LIBS = "1";
      ONNX_VERIFY_PROTO3 = "1";
    };

    cmakeFlags = map (name: cmakeFeature name finalAttrs.env.${name}) (attrNames finalAttrs.env);

    # Re-export the `cmakeFlags` environment variable as CMAKE_ARGS so setup.py will pick them up, then exit
    # the build directory for the python build.
    # TODO: How does bash handle accessing `cmakeFlags` as an array when __structuredAttrs is not set?
    postConfigure = ''
      export CMAKE_ARGS="$cmakeFlags"
      cd "$NIX_BUILD_TOP/$sourceRoot"
    '';

    postInstall =
      # After the python install is complete, re-enter the build directory to install the C++ components.
      ''
        pushd "''${cmakeBuildDir:?}"
        echo "Running CMake install for C++ components"
        make install -j ''${NIX_BUILD_CORES:?}
        popd
      ''
      # Patch up the include directory to avoid allowing downstream consumers choose between onnx and onnx-ml, since that's an innate
      # part of the library we've produced.
      + ''
        echo "Patching $out/include/onnx/onnx_pb.h"
        substituteInPlace "$out/include/onnx/onnx_pb.h" \
          --replace-fail \
            "#ifdef ONNX_ML" \
            "#if ''${ONNX_ML:?}"
      ''
      # Symlink the protobuf files in the python package to the C++ include directory.
      # TODO: Should these only be available to the python package?
      + ''
        echo "Symlinking protobuf files to $out/include/onnx"
        pushd "$out/${python3.sitePackages}/onnx"
        ln -srt "$out/include/onnx/" *.proto
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
    ];

    checkInputs = [
      gtest
    ];

    preCheck =
      ''
        echo "Running C++ tests"
        "''${cmakeBuildDir:?}/onnx_gtests"
      ''
      # Fixups for pytest
      + ''
        export HOME="$(mktemp --directory)"
        trap "rm -rf -- ''${HOME@Q}" EXIT
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
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      maintainers = (with maintainers; [ connorbaker ]) ++ teams.cuda.members;
    };
  };
in
buildPythonPackage finalAttrs
