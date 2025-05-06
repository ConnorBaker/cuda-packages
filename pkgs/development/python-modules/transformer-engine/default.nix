{
  buildPythonPackage,
  cmake,
  config,
  cudaPackages,
  fetchFromGitHub,
  fetchpatch2,
  importlib-metadata,
  lib,
  ninja,
  nvdlfw-inspect,
  pkgsBuildHost,
  pydantic,
  setuptools,
  torch,
  wheel,
}:
let
  inherit (cudaPackages)
    cuda_cudart
    cuda_nvcc
    cuda_nvml_dev
    cuda_nvrtc
    cuda_nvtx
    cuda_profiler_api
    cudnn
    flags
    libcublas
    libcusolver
    libcusparse
    ;
  inherit (lib.attrsets) getBin getLib getOutput;
in
buildPythonPackage {
  __structuredAttrs = true;

  pname = "transformer_engine";
  version = "2.2-unstable-2025-05-05";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "TransformerEngine";
    rev = "5bee81e2f4edc7ff10908d0943cba84a9831fde5";
    fetchSubmodules = true;
    # TODO: Use our cudnn-frontend and googletest
    hash = "sha256-2rU37OuEmUVOlUjhi1KllSSJyuFixY1Tn7XpkFexHP8=";
  };

  patches = [
    # https://github.com/NVIDIA/TransformerEngine/pull/1733
    (fetchpatch2 {
      name = "pr-1733.patch";
      url = "https://github.com/NVIDIA/TransformerEngine/commit/753242305d6a3186a2baf541b16c14fc20655f05.patch";
      hash = "sha256-MfjiTAQ61PI8YTgGnklDbPpMF7YACB00jGa/ihJCl0E=";
    })
    # https://github.com/NVIDIA/TransformerEngine/pull/1736
    (fetchpatch2 {
      name = "pr-1736.patch";
      url = "https://github.com/NVIDIA/TransformerEngine/commit/218e45c95c0db5c0a3db235d0a69067d2e41382e.patch";
      hash = "sha256-dpcU+SlbW3LLYptaRsg5m90Z+qQF+FObnV10LyFUrOA=";
    })
  ];

  pyproject = true;

  # TODO: Build seems to only process one job at a time.

  postPatch =
    # Patch out the wonky CUDNN and NVRTC loading code by replacing the docstrings.
    ''
      nixLog "patching out dlopen calls to CUDNN and NVRTC"
      substituteInPlace "$PWD/transformer_engine/common/__init__.py" \
        --replace-fail \
          '"""Load CUDNN shared library."""' \
          'return ctypes.CDLL("${getLib cudnn}/lib/libcudnn.so", mode=ctypes.RTLD_GLOBAL)' \
        --replace-fail \
          '"""Load NVRTC shared library."""' \
          'return ctypes.CDLL("${getLib cuda_nvrtc}/lib/libnvrtc.so", mode=ctypes.RTLD_GLOBAL)'
    ''
    # Replace the default /usr/local/cuda path with the one for cuda_cudart headers.
    # https://github.com/NVIDIA/TransformerEngine/blob/main/transformer_engine/common/util/cuda_runtime.cpp#L120-L124
    + ''
      nixLog "patching out cuda_runtime.cpp to use Nixpkgs CUDA packaging"
      substituteInPlace "$PWD/transformer_engine/common/util/cuda_runtime.cpp" \
        --replace-fail \
          '{"", "/usr/local/cuda"}' \
          '{"", "${getOutput "include" cuda_cudart}/include"}'
    ''
    # Allow newer versions of flash-attention to be used.
    + ''
      nixLog "patching out flash-attention version check"
      substituteInPlace "$PWD/transformer_engine/pytorch/attention/dot_product_attention/utils.py" \
        --replace-fail \
          'max_version = PkgVersion("2.7.4.post1")' \
          'max_version = PkgVersion("2.99.99")'
    ''
    # Patch the setup script to recognize our Python packages
    + ''
      nixLog "patching setup.py to use Nixpkgs Python packaging"
      local -a packageNames=(
        nvidia-cuda-runtime-cu12
        nvidia-cublas-cu12
        nvidia-cudnn-cu12
        nvidia-cuda-cccl-cu12
        nvidia-cuda-nvcc-cu12
        nvidia-nvtx-cu12
        nvidia-cuda-nvrtc-cu12
      )
      for packageName in "''${packageNames[@]}"; do
        substituteInPlace "$PWD/setup.py" \
          --replace-fail \
            "\"$packageName\"," \
            ""
      done
      unset -v packageNames
    '';

  preConfigure = ''
    export CUDA_HOME="${getBin pkgsBuildHost.cudaPackages.cuda_nvcc}"
    export NVTE_CUDA_ARCHS="${flags.cmakeCudaArchitecturesString}"
    export NVTE_FRAMEWORK=pytorch
  '';

  # TODO: Setting the release build environment variable pulls in fewer dependencies?
  # NOTE: It also does not build `transformer_engine_torch.cpython-312-x86_64-linux-gnu.so`, which we need.
  # export NVTE_RELEASE_BUILD=1

  build-system = [
    cmake
    ninja
    setuptools
    wheel
  ];

  nativeBuildInputs = [ cuda_nvcc ];

  dontUseCmakeConfigure = true;

  enableParallelBuilding = true;

  dependencies = [
    importlib-metadata
    nvdlfw-inspect
    pydantic
    torch
  ];

  buildInputs = [
    cuda_cudart
    cuda_nvml_dev
    cuda_nvrtc
    cuda_nvtx
    cuda_profiler_api
    cudnn
    libcublas
    libcusolver
    libcusparse
  ];

  # TODO: Add tests.
  doCheck = false;

  pythonImportsCheck = [ "transformer_engine" ];

  meta = {
    description = "Accelerate Transformer models on NVIDIA GPUs";
    homepage = "https://github.com/NVIDIA/TransformerEngine";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ connorbaker ];
    broken = !config.cudaSupport;
  };
}
