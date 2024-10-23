{
  backendStdenv,
  cmake,
  cuda_cudart,
  lib,
  python3,
  tensorrt,
  tensorrt-oss,
}:
let
  inherit (lib.lists) elemAt;
  inherit (lib.strings) cmakeFeature;
  inherit (lib.versions) splitVersion;
  inherit (python3.pkgs)
    buildPythonPackage
    pybind11
    setuptools
    wheel
    ;

  pythonVersionComponents = splitVersion python3.version;
  pythonMajorVersion = elemAt pythonVersionComponents 0;
  pythonMinorVersion = elemAt pythonVersionComponents 1;
  tensorRTMajorMinorPatchVersion = tensorrt-oss.version;
in
buildPythonPackage {
  # Must opt-out of __structuredAttrs which is on by default in our stdenv, but currently incompatible with Python
  # packaging: https://github.com/NixOS/nixpkgs/pull/347194.
  __structuredAttrs = false;
  stdenv = backendStdenv;

  pname = "tensorrt-python";

  inherit (tensorrt-oss) src version;

  sourceRoot = "source/python";

  pyproject = true;

  build-system = [
    setuptools
    wheel
  ];

  nativeBuildInputs = [
    cmake
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
        'find_path(PY_INCLUDE Python.h HINTS ''${EXT_PATH}/''${PYTHON} PATH_SUFFIXES include)' \
        'find_path(PY_INCLUDE Python.h HINTS "${python3}/include/''${PYTHON}" PATH_SUFFIXES include)'
    ''
    # Patch files in packaging
    + ''
      for file in $(find packaging -type f)
      do
        substituteInPlace "$file" \
          --replace-quiet \
            '##TENSORRT_VERSION##' \
            '${tensorrt.version}' \
          --replace-quiet \
            '##TENSORRT_MAJMINPATCH##' \
            '${tensorRTMajorMinorPatchVersion}'
      done
    '';

  cmakeFlags = [
    (cmakeFeature "CMAKE_BUILD_TYPE" "Release")
    (cmakeFeature "EXT_PATH" "/dev/null") # Must be set, too lazy to patch around it
    (cmakeFeature "PYTHON_MAJOR_VERSION" pythonMajorVersion)
    (cmakeFeature "PYTHON_MINOR_VERSION" pythonMinorVersion)
    (cmakeFeature "TARGET" "aarch64") # Only ever building for Jetsons in this derivation
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
      cp -r ./tensorrt ../packaging/
    ''
    # Move to packaging, which contains setup.py, for the Python build.
    + ''
      cd ../packaging
    '';

  buildInputs = [
    cuda_cudart
    pybind11 # In buildInputs instead of dependencies so CMake can find it
    tensorrt
  ];

  doCheck = true;

  meta = with lib; {
    description = "Open Source Software (OSS) components of NVIDIA TensorRT";
    homepage = "https://github.com/NVIDIA/TensorRT";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = with maintainers; [ connorbaker ] ++ teams.cuda.members;
  };
}
