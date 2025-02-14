{
  abseil-cpp,
  buildPythonPackage,
  cmake,
  fetchFromGitHub,
  google-re2,
  gtest,
  lib,
  nbval,
  numpy,
  parameterized,
  patchelf,
  pillow,
  protobuf_24 ? null,
  protobuf_25 ? null,
  pybind11,
  pytestCheckHook,
  python3,
  setuptools,
  tabulate,
}:
let
  inherit (builtins) storeDir;
  inherit (lib) licenses maintainers teams;
  inherit (lib.attrsets) attrNames;
  inherit (lib.lists) map;
  inherit (lib.meta) getExe;
  inherit (lib.strings) cmakeFeature;
  inherit (lib.versions) major;

  inherit
    (
      let
        hasCppProtobuf25 = protobuf_25 != null;
        hasCppProtobuf24 = protobuf_24 != null;
        hasPyProtobuf5 =
          python3.pkgs.protobuf5 or null != null || (major python3.pkgs.protobuf.version == "5");
        hasPyProtobuf4 =
          python3.pkgs.protobuf4 or null != null || (major python3.pkgs.protobuf.version == "4");
      in
      if hasCppProtobuf25 && hasPyProtobuf5 then
        {
          cppProtobuf = protobuf_25;
          pyProtobuf = python3.pkgs.protobuf5 or python3.pkgs.protobuf;
        }
      else if hasCppProtobuf24 && hasPyProtobuf4 then
        {
          cppProtobuf = protobuf_24;
          pyProtobuf = python3.pkgs.protobuf4 or python3.pkgs.protobuf;
        }
      else
        throw "Invalid set of protobuf"
    )
    cppProtobuf
    pyProtobuf
    ;

  finalAttrs = {
    # Must opt-out of __structuredAttrs which is set to true by default by cudaPackages.callPackage, but currently
    # incompatible with Python packaging: https://github.com/NixOS/nixpkgs/pull/347194.
    __structuredAttrs = false;

    pname = "onnx";

    version = "1.17.0-unstable-2024-08-27";

    src = fetchFromGitHub {
      owner = "onnx";
      repo = "onnx";
      # Merge commit for https://github.com/onnx/onnx/pull/6283, which should be included in 1.18
      rev = "f22a2ad78c9b8f3bd2bb402bfce2b0079570ecb6";
      hash = "sha256-YcmVGMLDxc60OM5290f4EG6UXdRALftXRRyrcUIPrlQ=";
    };

    pyproject = true;

    # NOTE: The project can not take advantage of ninja (as of 1.17.0).
    build-system = [
      cmake
      pyProtobuf
      setuptools
    ];

    nativeBuildInputs = [
      abseil-cpp
      cppProtobuf
      pybind11
    ];

    # Patch script template
    postPatch = ''
      chmod +x tools/protoc-gen-mypy.sh.in
      patchShebangs tools/protoc-gen-mypy.sh.in
    '';

    buildInputs = [
      abseil-cpp
      cppProtobuf
    ];

    dependencies = [
      abseil-cpp
      numpy
      pyProtobuf
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
      nixLog "exporting cmakeFlags as CMAKE_ARGS"
      export CMAKE_ARGS="$cmakeFlags"
      nixLog "returning to sourceRoot to install Python components"
      cd "$NIX_BUILD_TOP/$sourceRoot"
    '';

    postInstall =
      # After the python install is complete, re-enter the build directory to install the C++ components.
      ''
        nixLog "returning to ''${cmakeBuildDir:?} directory to install C++ components"
        pushd "''${cmakeBuildDir:?}"
        nixLog "running CMake install for C++ components"
        make install -j ''${NIX_BUILD_CORES:?}
        popd
      ''
      # Patch up the include directory to avoid allowing downstream consumers choose between onnx and onnx-ml, since that's an innate
      # part of the library we've produced.
      + ''
        nixLog "patching $out/include/onnx/onnx_pb.h"
        substituteInPlace "$out/include/onnx/onnx_pb.h" \
          --replace-fail \
            "#ifdef ONNX_ML" \
            "#if ''${ONNX_ML:?}"
      ''
      # Symlink the protobuf files in the python package to the C++ include directory.
      # TODO: Should these only be available to the python package?
      + ''
        nixLog "symlinking protobuf files to $out/include/onnx"
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
        nixLog "running C++ tests"
        "''${cmakeBuildDir:?}/onnx_gtests"
      ''
      # Fixups for pytest
      + ''
        nixLog "setting HOME to a temporary directory for pytest"
        export HOME="$(mktemp --directory)"
        trap "rm -rf -- ''${HOME@Q}" EXIT
      ''
      # Detecting source dir as a python package confuses pytest and causes import errors
      + ''
        nixLog "moving onnx/__init__.py to onnx/__init__.py.hidden"
        mv onnx/__init__.py onnx/__init__.py.hidden
      '';

    pythonImportsCheck = [ "onnx" ];

    # Some libraries maintain a reference to /build/source, so we need to remove the reference.
    preFixup = ''
      nixLog "patching shared libraries to remove references to build directory"
      find "$out" \
        -type f \
        -name '*.so' \
        -exec "${getExe patchelf}" \
          --remove-rpath \
          --shrink-rpath \
          --allowed-rpath-prefixes "${storeDir}" \
          '{}' \;
    '';

    passthru = {
      inherit
        cppProtobuf
        pyProtobuf
        ;
    };

    meta = {
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
