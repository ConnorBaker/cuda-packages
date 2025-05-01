{
  addDriverRunpath,
  buildPythonPackage,
  cuda-bindings,
  cuda-python,
  cudaPackages,
  cython,
  fetchFromGitHub,
  lib,
  numpy,
  pyclibrary,
  pytest,
  python,
  pythonOlder,
  runCommand,
  setuptools,
  symlinkJoin,
}:
let
  inherit (cudaPackages)
    cuda_cudart
    cuda_nvcc
    cuda_nvrtc
    cuda_profiler_api
    cudaMajorMinorVersion
    ;
  inherit (lib.attrsets)
    getLib
    getOutput
    hasAttr
    optionalAttrs
    ;
  inherit (lib.lists) map optionals;
  inherit (lib.strings) optionalString versionAtLeast versionOlder;
  inherit (lib.versions) majorMinor;
  majorMinorVersion = majorMinor finalAttrs.version;

  # Only needed for the 12.2 release, which has a different source layout.
  # Later releases shunted the CUDA bindings into a separate package (cuda-bindings).
  cudaHome = symlinkJoin {
    name = "cuda-home";
    paths = map (getOutput "include") [
      cuda_cudart
      cuda_nvcc
      cuda_nvrtc
      cuda_profiler_api
    ];
  };

  versions = {
    "12.2" = "12.2.1";
    "12.6" = "12.6.2.post1";
    "12.8" = "12.8.0";
  };

  hashes = {
    "12.2.1" = "sha256-zIsQt6jLssvzWmTgP9S8moxzzyPNpNjfcGgmAA2v2E8=";
    "12.6.2.post1" = "sha256-MG6q+Hyo0H4XKZLbtFQqfen6T2gxWzyk1M9jWryjjj4=";
    "12.8.0" = "sha256-7e9w70KkC6Pcvyu6Cwt5Asrc3W9TgsjiGvArRTer6Oc=";
  };

  finalAttrs = {
    __structuredAttrs = true;

    pname = "cuda-python";
    version = versions.${cudaMajorMinorVersion} or "unavailable";

    disabled = pythonOlder "3.7";

    src = fetchFromGitHub {
      owner = "NVIDIA";
      repo = "cuda-python";
      tag = "v${finalAttrs.version}";
      hash = hashes.${finalAttrs.version} or "";
    };

    sourceRoot =
      if finalAttrs.version == "12.2.1" then
        finalAttrs.src.name
      else if finalAttrs.version == "12.6.2.post1" then
        "${finalAttrs.src.name}/cuda_core"
      else if finalAttrs.version == "12.8.0" then
        "${finalAttrs.src.name}/cuda_python"
      else
        builtins.throw "Unsupported CUDA version: ${finalAttrs.version}";

    pyproject = true;

    build-system =
      [ setuptools ]
      ++ optionals (versionOlder finalAttrs.version "12.6") [ pyclibrary ]
      ++ optionals (versionOlder finalAttrs.version "12.8") [ cython ];

    # Replace relative dlopen calls with absolute paths to the libraries
    # NOTE: For cuda_nvcc, the nnvm directory is in the bin output.
    # NOTE: For cuda_cudart, post-12.8 the file has changed from cuda/bindings/_lib/cyruntime/cyruntime.pyx.in to
    # cuda/bindings/cyruntime.pyx.in.
    # NOTE: Post-12.8, cuda/bindings/_internal/nvvm_linux.pyx will need to be patched for libnvvm.so.
    postPatch = optionalString (versionOlder finalAttrs.version "12.6") ''
      nixLog "patching $PWD/cuda/_cuda/cnvrtc.pyx.in to replace relative dlopen"
      substituteInPlace "$PWD/cuda/_cuda/cnvrtc.pyx.in" \
        --replace-fail \
          "handle = dlfcn.dlopen('libnvrtc.so.12'" \
          "handle = dlfcn.dlopen('${getLib cuda_nvrtc}/lib/libnvrtc.so.12'"

      nixLog "patching $PWD/cuda/_cuda/ccuda.pyx.in to replace relative dlopen"
      substituteInPlace "$PWD/cuda/_cuda/ccuda.pyx.in" \
        --replace-fail \
          "handle = dlfcn.dlopen(bytes(path, encoding='utf-8'), dlfcn.RTLD_NOW)" \
          "handle = dlfcn.dlopen(bytes('${addDriverRunpath.driverLink}/lib/libcuda.so.1', encoding='utf-8'), dlfcn.RTLD_NOW)"
    '';

    preConfigure = optionalString (versionOlder finalAttrs.version "12.6") ''
      export CUDA_HOME="${cudaHome}";
      export PARALLEL_LEVEL="$NIX_BUILD_CORES"
    '';

    dependencies =
      optionals (majorMinorVersion == "12.6") [ numpy ]
      ++ optionals (versionAtLeast finalAttrs.version "12.6") [ cuda-bindings ];

    # NOTE: Tests are in the cuda-bindings package.
    doCheck = false;

    enableParallelBuilding = true;

    pythonImportsCheck = [ "cuda" ];

    passthru.tests = optionalAttrs (versionOlder finalAttrs.version "12.6") {
      # Only CUDA 12.2 release has tests in the source for cuda-python;
      # Later releases have tests for cuda-bindings.
      python-unit-tests =
        runCommand "cuda-python-unit-tests"
          {
            __structuredAttrs = true;
            strictDeps = true;
            nativeBuildInputs = [
              cuda-python
              numpy
              pytest
              python
            ];
            requiredSystemFeatures = [ "cuda" ];
          }
          ''
            set -euo pipefail
            cp -rv "${cuda-python.src}/cuda/tests"/* .
            chmod +w -R .
            pytest .
            touch "$out"
          '';
    };

    meta = {
      description = "The home for accessing NVIDIA's CUDA platform from Python";
      homepage = "https://nvidia.github.io/cuda-python/";
      broken = !(hasAttr cudaMajorMinorVersion versions);
      license = {
        fullName = "NVIDIA Software License Agreement";
        shortName = "NVIDIA SLA";
        url = "https://github.com/NVIDIA/cuda-python/blob/2aca3064514855fb0d9766880faf7ab623bdccc9/LICENSE";
        free = false;
      };
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      maintainers = with lib.maintainers; [ connorbaker ];
    };
  };
in
buildPythonPackage finalAttrs
