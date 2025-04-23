{
  fetchFromGitHub,
  gtest,
  lib,
  patchelf,
  protobuf_24 ? null,
  protobuf_25 ? null,
  python3Packages,
  pythonSupport ? true,
  stdenv,
}:
let
  inherit (builtins) storeDir;
  inherit (lib) licenses maintainers teams;
  inherit (lib.attrsets) attrNames;
  inherit (lib.lists) map optionals;
  inherit (lib.meta) getExe;
  inherit (lib.strings) cmakeFeature optionalString;
  inherit (lib.versions) major;
  inherit (python3Packages) python;

  inherit
    (
      let
        hasCppProtobuf25 = protobuf_25 != null;
        hasCppProtobuf24 = protobuf_24 != null;
        hasPyProtobuf5 =
          python3Packages.protobuf5 or null != null || (major python3Packages.protobuf.version == "5");
        hasPyProtobuf4 =
          python3Packages.protobuf4 or null != null || (major python3Packages.protobuf.version == "4");
      in
      if hasCppProtobuf25 && hasPyProtobuf5 then
        {
          cppProtobuf = protobuf_25;
          pyProtobuf = python3Packages.protobuf5 or python3Packages.protobuf;
        }
      else if hasCppProtobuf24 && hasPyProtobuf4 then
        {
          cppProtobuf = protobuf_24;
          pyProtobuf = python3Packages.protobuf4 or python3Packages.protobuf;
        }
      else
        throw "Invalid set of protobuf"
    )
    cppProtobuf
    pyProtobuf
    ;
in
stdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;

  pname = "onnx";
  version = "1.17.0-unstable-2024-08-27";

  src = fetchFromGitHub {
    owner = "onnx";
    repo = "onnx";
    # Merge commit for https://github.com/onnx/onnx/pull/6283, which should be included in 1.18
    rev = "f22a2ad78c9b8f3bd2bb402bfce2b0079570ecb6";
    hash = "sha256-YcmVGMLDxc60OM5290f4EG6UXdRALftXRRyrcUIPrlQ=";
  };

  outputs = [
    "out"
    "dev"
  ] ++ optionals pythonSupport [ "dist" ];

  nativeBuildInputs =
    [
      cppProtobuf
      python # NOTE: apparently required regardless of pythonSupport
      # NOTE: We need CMake for both the non-python and python builds, but we don't want two copies of it on the path.
      # The cmake python package seems to work for both, so we use that.
      python3Packages.cmake
    ]
    ++ optionals pythonSupport (
      with python3Packages;
      [
        build
        pybind11
        pythonOutputDistHook
        setuptools
      ]
    );

  # Patch script template
  postPatch = ''
    chmod +x tools/protoc-gen-mypy.sh.in
    patchShebangs tools/protoc-gen-mypy.sh.in
  '';

  buildInputs = [ cppProtobuf ] ++ optionals pythonSupport [ pyProtobuf ];

  # Declared in setup.py
  cmakeBuildDir = ".setuptools-cmake-build";

  # Python setup.py just takes stuff from the environment.
  env = {
    BUILD_SHARED_LIBS = "1";
    ONNX_BUILD_BENCHMARKS = "0";
    ONNX_BUILD_PYTHON = if pythonSupport then "1" else "0";
    ONNX_BUILD_SHARED_LIBS = "1";
    ONNX_BUILD_TESTS = if finalAttrs.doCheck then "1" else "0";
    ONNX_GEN_PB_TYPE_STUBS = "1";
    ONNX_ML = "1"; # NOTE: If this is `true`, onnx-tensorrt fails to build due to missing protobuf files.
    ONNX_NAMESPACE = "onnx";
    ONNX_USE_PROTOBUF_SHARED_LIBS = "1";
    ONNX_VERIFY_PROTO3 = "1";
  };

  cmakeFlags = map (name: cmakeFeature name finalAttrs.env.${name}) (attrNames finalAttrs.env);

  # Re-export the `cmakeFlags` environment variable as CMAKE_ARGS so setup.py will pick them up, do the python build from the top-level,
  # then continue the C++ build.
  buildPhase = lib.optionalString pythonSupport ''
    runHook preBuild

    pushd "$NIX_BUILD_TOP/$sourceRoot"
    nixLog "exporting cmakeFlags as CMAKE_ARGS for Python build"
    export CMAKE_ARGS="''${cmakeFlags[*]}"
    nixLog "building Python wheel"
    pyproject-build \
      --no-isolation \
      --outdir dist/ \
      --wheel
    popd >/dev/null

    runHook postBuild
  '';

  # Move the dist directory so the python dist output hook can find it.
  postBuild = optionalString pythonSupport ''
    mv -v "$NIX_BUILD_TOP/$sourceRoot/dist" "$PWD"
  '';

  # NOTE: Python specific tests happen in the python package.
  doCheck = true;

  checkInputs = [ gtest ];

  preCheck = ''
    nixLog "running C++ tests with $PWD/onnx_gtests"
    "$PWD/onnx_gtests"
  '';

  # Patch up the include directory to avoid allowing downstream consumers choose between onnx and onnx-ml, since that's an innate
  # part of the library we've produced.
  postInstall = ''
    nixLog "patching ''${!outputInclude:?}/include/onnx/onnx_pb.h"
    substituteInPlace "''${!outputInclude:?}/include/onnx/onnx_pb.h" \
      --replace-fail \
        "#ifdef ONNX_ML" \
        "#if ''${ONNX_ML:?}"
  '';

  # Some libraries maintain a reference to /build/source, so we need to remove the reference.
  preFixup = ''
    nixLog "patching shared libraries to remove references to build directory"
    find "''${!outputLib:?}" \
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

  # TODO(@connorbaker): This derivation should contain CPP tests for onnx.

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
})
