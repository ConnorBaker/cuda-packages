{
  autoPatchelfHook,
  build,
  buildPythonPackage,
  cmake,
  cudaLib,
  cudaPackages,
  fetchFromGitHub,
  fetchpatch2,
  lib,
  onnx-tensorrt,
  onnx,
  pybind11,
  pypaInstallHook,
  python,
  runCommand,
  setuptools,
  stdenv,
}:
let
  inherit (cudaLib.utils) majorMinorPatch;
  inherit (cudaPackages) cuda_cudart cudaStdenv tensorrt;
  inherit (lib) licenses maintainers teams;
  inherit (lib.attrsets) getLib getOutput;
  inherit (lib.lists) elemAt optionals;
  inherit (lib.strings) cmakeFeature;
  inherit (lib.versions) splitVersion;

  pythonVersionComponents = splitVersion python.version;
  pythonMajorVersion = elemAt pythonVersionComponents 0;
  pythonMinorVersion = elemAt pythonVersionComponents 1;

  # This allows us to break a circular dependency on onnx-tensorrt, which requires tensorrt-python.
  # We only need the header files.
  onnx-tensorrt-headers =
    runCommand "onnx-tensorrt-headers"
      {
        strictDeps = true;
        inherit (onnx-tensorrt) meta version;
        # We want the src for the wheel, not the wheel itself.
        inherit (onnx-tensorrt.src) src;
      }
      ''
        cd "$src"
        mkdir -p "$out/include/onnx"
        install -Dm644 *.h *.hpp "$out/include/onnx"
      '';

  finalAttrs = {
    __structuredAttrs = true;
    strictDeps = true;

    pname = "tensorrt";

    version = majorMinorPatch tensorrt.version;

    src = fetchFromGitHub {
      owner = "NVIDIA";
      repo = "TensorRT";
      tag = "v${finalAttrs.version}";
      hash =
        {
          "10.7.0" = "sha256-sbp61GverIWrHKvJV+oO9TctFTO4WUmH0oInZIwqF/s=";
          "10.9.0" = "sha256-J8K9RjeGIem5ZxXyU+Rne8uBbul54ie6P/Y1In2mQ0g=";
        }
        .${finalAttrs.version};
    };

    patches = optionals (finalAttrs.version == "10.9.0") [
      # https://github.com/NVIDIA/TensorRT/pull/4434
      (fetchpatch2 {
        name = "cmake-fix-templating-of-sm-architecture.patch";
        url = "https://github.com/NVIDIA/TensorRT/commit/9e0835ac8a8f07c8f7194d7b174282bac3b23550.patch";
        hash = "sha256-Bj4k/9Heq3CPayDl5azVTYuRUkc/KT8ESwgwBXdJvmg=";
      })
    ];

    build-system = [
      build
      cmake
      setuptools
    ];

    nativeBuildInputs = [
      onnx.passthru.cppProtobuf
      pypaInstallHook
    ] ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ]; # included to fail on missing dependencies

    postPatch =
      ''
        nixLog "patching $PWD/CMakeLists.txt to avoid manually setting CMAKE_CXX_COMPILER"
        substituteInPlace "$PWD"/CMakeLists.txt \
          --replace-fail \
            'find_program(CMAKE_CXX_COMPILER NAMES $ENV{CXX} g++)' \
            '# find_program(CMAKE_CXX_COMPILER NAMES $ENV{CXX} g++)'

        nixLog "patching $PWD/CMakeLists.txt to use find_package(CUDAToolkit) instead of find_package(CUDA)"
        substituteInPlace "$PWD"/CMakeLists.txt \
          --replace-fail \
            'find_package(CUDA ''${CUDA_VERSION} REQUIRED)' \
            'find_package(CUDAToolkit REQUIRED)'

        nixLog "patching $PWD/python/CMakeLists.txt to correct hints for python3"
        substituteInPlace "$PWD"/python/CMakeLists.txt \
          --replace-fail \
            'HINTS ''${EXT_PATH}/''${PYTHON} /usr/include/''${PYTHON}' \
            'HINTS "${python}/include/''${PYTHON}"'

        for script in "$PWD"/python/packaging/bindings_wheel/tensorrt/plugin/_{lib,tensor,top_level}.py; do
          nixLog "patching $script to remove invalid escape sequence '\s'"
          substituteInPlace "$script" --replace-fail '\s' 's'
        done
      ''
      # Patch files in packaging
      # Largely taken from https://github.com/NVIDIA/TensorRT/blob/08ad45bf3df848e722dfdc7d01474b5ba2eff7e9/python/build.sh.
      + ''
        for file in $(find "$PWD"/python/packaging -type f); do
          nixLog "patching $file to include TensorRT version"
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

    cmakeBuildDir = "python/build";

    # The CMakeLists.txt file is in the python directory, one level up from the build directory.
    cmakeDir = "..";

    cmakeFlags = [
      (cmakeFeature "CMAKE_BUILD_TYPE" "Release")
      (cmakeFeature "TENSORRT_MODULE" "tensorrt")
      (cmakeFeature "EXT_PATH" "/dev/null") # Must be set, too lazy to patch around it
      (cmakeFeature "PYTHON_MAJOR_VERSION" pythonMajorVersion)
      (cmakeFeature "PYTHON_MINOR_VERSION" pythonMinorVersion)
      (cmakeFeature "TARGET" stdenv.hostPlatform.parsed.cpu.name)
    ];

    # Allow CMake to perform the build.
    dontUseSetuptoolsBuild = true;

    postBuild = ''
      nixLog "copying build artifacts to $NIX_BUILD_TOP/$sourceRoot/python/packaging/bindings_wheel"
      cp -rv "$PWD/tensorrt" "$NIX_BUILD_TOP/$sourceRoot/python/packaging/bindings_wheel"

      pushd "$NIX_BUILD_TOP/$sourceRoot/python/packaging/bindings_wheel"
      nixLog "building Python wheel from $PWD"
      pyproject-build \
        --no-isolation \
        --outdir "$NIX_BUILD_TOP/$sourceRoot/''${cmakeBuildDir:?}/dist/" \
        --wheel
      popd >/dev/null
    '';

    buildInputs = [
      (getLib tensorrt)
      (getOutput "include" tensorrt)
      cuda_cudart
      onnx
      onnx-tensorrt-headers
      pybind11
    ];

    doCheck = false; # This derivation produces samples that require a GPU to run.

    # On Jetson, trying to import the package requires `libnvdla_compiler.so` (from the host driver) be available.
    pythonImportsCheck = optionals (!cudaStdenv.hasJetsonCudaCapability) [ "tensorrt" ];

    meta = {
      description = "Open Source Software (OSS) components of NVIDIA TensorRT";
      homepage = "https://github.com/NVIDIA/TensorRT";
      license = licenses.asl20;
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      maintainers = (with maintainers; [ connorbaker ]) ++ teams.cuda.members;
    };

    # TODO(@connorbaker): This derivation should contain Python tests for tensorrt.
  };
in
buildPythonPackage finalAttrs
