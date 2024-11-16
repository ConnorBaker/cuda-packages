{
  backendStdenv,
  cuda_cudart,
  lib,
  onnx-tensorrt,
  python3,
  runCommand,
  tensorrt,
  tensorrt-oss,
}:
let
  inherit (lib.lists) elemAt;
  inherit (lib.strings) cmakeFeature;
  inherit (lib.versions) splitVersion;
  inherit (python3.pkgs)
    buildPythonPackage
    cmake
    pybind11
    setuptools
    wheel
    ;

  pythonVersionComponents = splitVersion python3.version;
  pythonMajorVersion = elemAt pythonVersionComponents 0;
  pythonMinorVersion = elemAt pythonVersionComponents 1;
  tensorRTMajorMinorPatchVersion = tensorrt-oss.version;

  # This allows us to break a circular dependency on onnx-tensorrt, which requires tensorrt-python.
  # We only need the header files.
  onnx-tensorrt-headers =
    runCommand "onnx-tensorrt-headers"
      {
        strictDeps = true;
        inherit (onnx-tensorrt) src version;
        nativeBuildInputs = [ onnx-tensorrt.src ];
      }
      ''
        mkdir -p "$out/include/onnx"
        cd "${onnx-tensorrt.src}"
        install -Dm644 *.h *.hpp "$out/include/onnx"
      '';

  finalAttrs = {
    # Must opt-out of __structuredAttrs which is on by default in our stdenv, but currently incompatible with Python
    # packaging: https://github.com/NixOS/nixpkgs/pull/347194.
    __structuredAttrs = false;
    stdenv = backendStdenv;

    pname = "tensorrt-python";

    inherit (tensorrt-oss) version;

    src = "${tensorrt-oss.src}/python";

    pyproject = true;

    # NOTE: The project, as of 10.6, does not use ninja for the Python portion.
    build-system = [
      cmake
      setuptools
      wheel
    ];

    postPatch =
      # Patch the python CMakeLists.txt to use our supplied packages.
      ''
        substituteInPlace CMakeLists.txt \
        --replace-fail \
          'find_path(PYBIND11_DIR pybind11/pybind11.h HINTS ''${EXT_PATH} ''${WIN_EXTERNALS} PATH_SUFFIXES pybind11/include)' \
          'find_package(pybind11 REQUIRED CONFIG)' \
        --replace-fail \
          'PYBIND11_DIR' \
          'pybind11_DIR' \
        --replace-fail \
          'find_path(PY_INCLUDE Python.h HINTS ''${EXT_PATH}/''${PYTHON} /usr/include/''${PYTHON} PATH_SUFFIXES include)' \
          'find_path(PY_INCLUDE Python.h HINTS "${python3}/include/''${PYTHON}" PATH_SUFFIXES include)'
      ''
      # Patch files in packaging
      # Largely taken from https://github.com/NVIDIA/TensorRT/blob/08ad45bf3df848e722dfdc7d01474b5ba2eff7e9/python/build.sh.
      + ''
        for file in $(find packaging -type f)
        do
          substituteInPlace "$file" \
            --replace-quiet \
              '##TENSORRT_VERSION##' \
              '${tensorrt.version}' \
            --replace-quiet \
              '##TENSORRT_MAJMINPATCH##' \
              '${tensorRTMajorMinorPatchVersion}' \
            --replace-quiet \
              '##TENSORRT_PYTHON_VERSION##' \
              '${tensorRTMajorMinorPatchVersion}' \
            --replace-quiet \
              '##TENSORRT_MODULE##' \
              'tensorrt'
        done
      '';

    cmakeFlags = [
      (cmakeFeature "CMAKE_BUILD_TYPE" "Release")
      (cmakeFeature "TENSORRT_MODULE" "tensorrt")
      (cmakeFeature "EXT_PATH" "/dev/null") # Must be set, too lazy to patch around it
      (cmakeFeature "PYTHON_MAJOR_VERSION" pythonMajorVersion)
      (cmakeFeature "PYTHON_MINOR_VERSION" pythonMinorVersion)
      (cmakeFeature "TARGET" (if backendStdenv.hostPlatform.isAarch then "aarch64" else "x86_64"))
    ];

    preBuild =
      # Before the Python build starts, build the C++ components with CMake. Since the CMake setup hook has placed us in
      # cmakeBuildDir, we don't need to change the dir.  
      ''
        echo "Running CMake build for C++ components"
        make all -j ''${NIX_BUILD_CORES:?}
      ''
      # Copy the build artifacts to packaging.
      + ''
        cp -r ./tensorrt ../packaging/bindings_wheel
      ''
      # Move to packaging, which contains setup.py, for the Python build.
      + ''
        cd ../packaging/bindings_wheel
      '';

    buildInputs = [
      cuda_cudart
      onnx-tensorrt-headers
      pybind11 # In buildInputs instead of dependencies so CMake can find it
      tensorrt
    ];

    doCheck = true;

    meta = with lib; {
      description = "Open Source Software (OSS) components of NVIDIA TensorRT";
      homepage = "https://github.com/NVIDIA/TensorRT";
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
