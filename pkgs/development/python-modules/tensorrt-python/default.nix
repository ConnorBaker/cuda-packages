{
  buildPythonPackage,
  cmake,
  config,
  cudaLib,
  cudaPackages,
  cudaSupport ? config.cudaSupport,
  fetchFromGitHub,
  lib,
  onnx-tensorrt,
  pybind11,
  python3,
  runCommand,
  setuptools,
  stdenv,
  wheel,
}:
let
  inherit (cudaLib.utils) majorMinorPatch;
  inherit (cudaPackages)
    cuda_cudart
    cuda_nvcc
    tensorrt
    ;
  inherit (lib) licenses maintainers teams;
  inherit (lib.attrsets) getOutput;
  inherit (lib.lists) elemAt;
  inherit (lib.strings) cmakeFeature;
  inherit (lib.versions) splitVersion;

  pythonVersionComponents = splitVersion python3.version;
  pythonMajorVersion = elemAt pythonVersionComponents 0;
  pythonMinorVersion = elemAt pythonVersionComponents 1;

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
    # Must opt-out of __structuredAttrs which is set to true by default by cudaPackages.callPackage, but currently
    # incompatible with Python packaging: https://github.com/NixOS/nixpkgs/pull/347194.
    __structuredAttrs = false;

    pname = "tensorrt-python";

    version = majorMinorPatch tensorrt.version;

    src = fetchFromGitHub {
      owner = "NVIDIA";
      repo = "TensorRT";
      tag = "v${finalAttrs.version}";
      hash =
        {
          "10.7.0" = "sha256-sbp61GverIWrHKvJV+oO9TctFTO4WUmH0oInZIwqF/s=";
          "10.8.0" = "sha256-SDlTZf8EQBq8vDCH3YFJCROHbf47RB5WUu4esLNpYuA=";
        }
        .${finalAttrs.version};
    };

    sourceRoot = "${finalAttrs.src.name}/python";

    pyproject = true;

    # NOTE: The project, as of 10.7, does not use ninja for the Python portion.
    build-system = [
      cmake
      setuptools
      wheel
    ];

    postPatch =
      ''
        nixLog "patching $PWD/CMakeLists.txt to correct hints for python3"
        substituteInPlace CMakeLists.txt \
          --replace-fail \
            'HINTS ''${EXT_PATH}/''${PYTHON} /usr/include/''${PYTHON}' \
            'HINTS "${python3}/include/''${PYTHON}"'
        for script in packaging/bindings_wheel/tensorrt/plugin/_{lib,tensor,top_level}.py; do
          nixLog "patching $PWD/$script to remove invalid escape sequence '\s'"
          substituteInPlace "$script" --replace-fail '\s' 's'
        done
      ''
      # Patch files in packaging
      # Largely taken from https://github.com/NVIDIA/TensorRT/blob/08ad45bf3df848e722dfdc7d01474b5ba2eff7e9/python/build.sh.
      + ''
        for file in $(find packaging -type f); do
          nixLog "patching $PWD/$file to include TensorRT version"
          substituteInPlace "$file" \
            --replace-quiet \
              '##TENSORRT_VERSION##' \
              '${tensorrt.version}' \
            --replace-quiet \
              '##TENSORRT_MAJMINPATCH##' \
              '${finalAttrs.version}' \
            --replace-quiet \
              '##TENSORRT_PYTHON_VERSION##' \
              '${finalAttrs.version}' \
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
      (cmakeFeature "TARGET" stdenv.hostPlatform.parsed.cpu.name)
    ];

    preBuild =
      # Before the Python build starts, build the C++ components with CMake. Since the CMake setup hook has placed us in
      # cmakeBuildDir, we don't need to change the dir.
      ''
        nixLog "running CMake build for C++ components"
        make all -j ''${NIX_BUILD_CORES:?}
      ''
      # Copy the build artifacts to packaging.
      + ''
        nixLog "copying build artifacts to packaging"
        cp -r ./tensorrt ../packaging/bindings_wheel
      ''
      # Move to packaging, which contains setup.py, for the Python build.
      + ''
        nixLog "moving to packaging for Python build"
        cd ../packaging/bindings_wheel
      '';

    dependencies = [ pybind11 ];

    buildInputs = [
      (getOutput "include" cuda_nvcc) # for crt/host_defines.h
      cuda_cudart
      onnx-tensorrt-headers
      tensorrt
    ];

    doCheck = true;

    # Copy the Python include directory to the output.
    postInstall = ''
      nixLog "installing Python header files"
      mkdir -p "$out/python"
      cp -r "$NIX_BUILD_TOP/$sourceRoot/include" "$out/python/"
    '';

    meta = {
      broken = !cudaSupport;
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
