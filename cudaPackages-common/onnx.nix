{
  abseil-cpp,
  backendStdenv,
  fetchFromGitHub,
  fetchpatch2,
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

  # Python setup.py just takes stuff from the environment.
  env = {
    BUILD_ONNX_PYTHON = "1";
    BUILD_SHARED_LIBS = "1";
    ONNX_BUILD_BENCHMARKS = "0";
    ONNX_BUILD_SHARED_LIBS = "1";
    ONNX_BUILD_TESTS = "1";
    ONNX_GEN_PB_TYPE_STUBS = "1";
    ONNX_ML = "1"; # NOTE: If this is `true`, onnx-tensorrt fails to build due to missing protobuf files.
    ONNX_NAMESPACE = "onnx";
    ONNX_USE_PROTOBUF_SHARED_LIBS = "1";
    ONNX_VERIFY_PROTO3 = "1";
  };
in
buildPythonPackage {
  # Must opt-out of __structuredAttrs which is on by default in our stdenv, but currently incompatible with Python
  # packaging: https://github.com/NixOS/nixpkgs/pull/347194.
  __structuredAttrs = false;
  stdenv = backendStdenv;

  pname = "onnx";
  version = "1.16.2";

  src = fetchFromGitHub {
    owner = "onnx";
    repo = "onnx";
    rev = "refs/tags/v1.16.2";
    hash = "sha256-JmxnsHRrzj2QzPz3Yndw0MmgZJ8MDYxHjuQ7PQkQsDg=";
  };
  pyproject = true;

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

  patches = [
    (fetchpatch2 {
      name = "onnx.patch";
      url = "https://raw.githubusercontent.com/microsoft/onnxruntime/refs/tags/v1.19.2/cmake/patches/onnx/onnx.patch";
      hash = "sha256-TKQXuPY55sJeAndOiauxK4nYd0VaXabtys8W71i+hKM=";
    })
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

  inherit env;

  cmakeFlags = map (name: cmakeFeature name env.${name}) (attrNames env);

  # Re-export the `cmakeFlags` environment variable as CMAKE_ARGS so setup.py will pick them up, then exit
  # the build directory for the python build.
  # TODO: How does bash handle accessing `cmakeFlags` as an array when __structuredAttrs is not set?
  postConfigure = ''
    export CMAKE_ARGS="''${cmakeFlags[@]}"
    cd ..
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
      pushd "$out/${python3.sitePackages}/onnx"
      echo "Symlinking protobuf files to $out/include/onnx"
      for file in *.proto
      do
        ln -s "$PWD/$file" "$out/include/onnx/$file"
      done
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

  checkInputs = [ gtest ];

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
    maintainers = with maintainers; [ connorbaker ];
  };
}
