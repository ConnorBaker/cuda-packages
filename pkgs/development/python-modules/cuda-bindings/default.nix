{
  buildPythonPackage,
  cuda-bindings,
  cuda-python,
  cudaPackages,
  cython,
  lib,
  numpy,
  pyclibrary,
  pytest,
  python,
  pythonOlder,
  runCommand,
  setuptools,
  versioneer,
}:
let
  inherit (cudaPackages)
    cuda_cudart
    cuda_profiler_api
    cuda_nvrtc
    libnvjitlink
    ;
  inherit (lib.attrsets) getLib;
  inherit (lib.lists) optionals;
  inherit (lib.versions) majorMinor;
  majorMinorVersion = majorMinor finalAttrs.version;
  finalAttrs = {
    __structuredAttrs = true;

    pname = "cuda-bindings";
    inherit (cuda-python) src version;

    disabled = pythonOlder "3.7";

    sourceRoot = "${finalAttrs.src.name}/cuda_bindings";

    pyproject = true;

    build-system = [
      cython
      pyclibrary
      setuptools
    ] ++ optionals (majorMinorVersion == "12.6") [ versioneer ];

    postPatch =
      # NOTE: This seems... wrong?
      # https://github.com/NVIDIA/cuda-python/blob/c04025db0888830cdbb769488f9b1f90ea3eb972/cuda_bindings/setup.py#L35C1-L35C40
      # They're splitting CUDA_HOME on os.pathsep and then using each component as a separate directory to search for
      # includes:
      # https://github.com/NVIDIA/cuda-python/blob/c04025db0888830cdbb769488f9b1f90ea3eb972/cuda_bindings/setup.py#L120
      # At any rate, have the script use the CUDAToolkit_ROOT environment variable, which is a semi-colon separated list of
      # all the CUDA packages in the environment. This variable is set by `cudaHook`.
      # NOTE: The reason the CUDA_HOME acquisition is short is because they change the call between versions:
      # "12.6.2.post1" = CUDA_HOME = os.environ.get("CUDA_HOME")
      # "12.8.0" = CUDA_HOME = os.environ.get("CUDA_HOME", os.environ.get("CUDA_PATH", None))
      # We want to patch either way, so use the shortest common prefix.
      ''
        nixLog "patching $PWD/setup.py to fix acquisition and parsing of CUDA_HOME"
        substituteInPlace "$PWD/setup.py" \
          --replace-fail \
            'CUDA_HOME = os.environ.get("CUDA_HOME"' \
            'CUDA_HOME = os.environ.get("CUDAToolkit_ROOT"' \
          --replace-fail \
            'CUDA_HOME = CUDA_HOME.split(os.pathsep)' \
            'CUDA_HOME = CUDA_HOME.split(";")'
      ''
      # Replace relative dlopen calls with absolute paths to the libraries
      # NOTE: For cuda_nvcc, the nnvm directory is in the bin output.
      # NOTE: For cuda_cudart, post-12.8 the file has changed from cuda/bindings/_lib/cyruntime/cyruntime.pyx.in to
      # cuda/bindings/cyruntime.pyx.in.
      # NOTE: Post-12.8, cuda/bindings/_internal/nvvm_linux.pyx will need to be patched for libnvvm.so.
      + ''
        nixLog "patching $PWD/cuda/bindings/_bindings/cynvrtc.pyx.in to replace relative dlopen"
        substituteInPlace "$PWD/cuda/bindings/_bindings/cynvrtc.pyx.in" \
          --replace-fail \
            "handle = dlfcn.dlopen('libnvrtc.so.12'" \
            "handle = dlfcn.dlopen('${getLib cuda_nvrtc}/lib/libnvrtc.so.12'"

        nixLog "patching $PWD/cuda/bindings/_lib/cyruntime/cyruntime.pyx.in to replace relative dlopen"
        substituteInPlace "$PWD/cuda/bindings/_lib/cyruntime/cyruntime.pyx.in" \
          --replace-fail \
            "handle = dlfcn.dlopen('libcudart.so.12'" \
            "handle = dlfcn.dlopen('${getLib cuda_cudart}/lib/libcudart.so.12'"

        nixLog "patching $PWD/cuda/bindings/_internal/nvjitlink_linux.pyx to replace relative dlopen"
        substituteInPlace "$PWD/cuda/bindings/_internal/nvjitlink_linux.pyx" \
          --replace-fail \
            'so_name = "libnvJitLink.so"' \
            'so_name = "${getLib libnvjitlink}/lib/libnvJitLink.so"'
      '';

    preConfigure =
      let
        parallelEnvName = {
          "12.2" = "PARALLEL_LEVEL";
          "12.6" = "PARALLEL_LEVEL";
          "12.8" = "CUDA_PYTHON_PARALLEL_LEVEL";
        };
      in
      ''
        export ${parallelEnvName.${majorMinorVersion}}="$NIX_BUILD_CORES"
      '';

    buildInputs = [
      cuda_cudart
      cuda_profiler_api
      cuda_nvrtc
    ];

    # Tests are in passthru.tests.
    doCheck = false;

    enableParallelBuilding = true;

    pythonImportsCheck = [ "cuda.bindings" ];

    passthru.tests = {
      # NOTE: benchmarks are a WIP and don't fully work, so they're not included.
      # NOTE: cython-unit-tests are not included because the files must be cythonized before running.
      python-unit-tests =
        runCommand "cuda-bindings-python-unit-tests"
          {
            __structuredAttrs = true;
            strictDeps = true;
            nativeBuildInputs = [
              cuda-bindings
              numpy
              pytest
              python
            ];
            requiredSystemFeatures = [ "cuda" ];
          }
          ''
            set -euo pipefail
            cp -rv "${cuda-bindings.src}/cuda_bindings/tests"/* .
            chmod +w -R .
            pytest .
            touch "$out"
          '';
      samples =
        runCommand "cuda-bindings-samples"
          {
            __structuredAttrs = true;
            strictDeps = true;
            env.CUDA_HOME = "/dev/null"; # Just needs to be set to something.
            nativeBuildInputs = [
              cuda-bindings
              numpy
              pytest
              python
            ];
            requiredSystemFeatures = [ "cuda" ];
          }
          ''
            set -euo pipefail
            cp -rv "${cuda-bindings.src}/cuda_bindings/examples"/* .
            chmod +w -R .
            pytest .
            touch "$out"
          '';
    };

    meta = {
      description = "Low-level CUDA interfaces";
      homepage = "https://nvidia.github.io/cuda-python/cuda-bindings/latest/overview.html";
      # TODO: Does not exist in the 12.2 version.
      inherit (cuda-python.meta) broken;
      license = {
        fullName = "NVIDIA Software License Agreement";
        shortName = "NVIDIA SLA";
        url = "https://github.com/NVIDIA/cuda-python/blob/c04025db0888830cdbb769488f9b1f90ea3eb972/cuda_bindings/LICENSE";
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
