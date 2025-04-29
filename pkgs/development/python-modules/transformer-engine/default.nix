{
  buildPythonPackage,
  cmake,
  config,
  cudaPackages,
  fetchFromGitHub,
  importlib-metadata,
  lib,
  ninja,
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
  version = "2.1-unstable-2025-04-08";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "TransformerEngine";
    rev = "9d4e11eaa508383e35b510dc338e58b09c30be73";
    fetchSubmodules = true;
    # TODO: Use our cudnn-frontend and googletest
    hash = "sha256-ELUM13VyZ3H9bFQgnM6+QvS8pJfuUkBsP1fAjxU3s5c=";
  };

  pyproject = true;

  # TODO: Build seems to only process one job at a time.

  postPatch =
    # Patch out the wonky CUDNN and NVRTC loading code by replacing the docstrings.
    ''
      substituteInPlace transformer_engine/common/__init__.py \
        --replace-fail \
          '"""Load CUDNN shared library."""' \
          'return ctypes.CDLL("${getLib cudnn}/lib/libcudnn.so", mode=ctypes.RTLD_GLOBAL)' \
        --replace-fail \
          '"""Load NVRTC shared library."""' \
          'return ctypes.CDLL("${getLib cuda_nvrtc}/lib/libnvrtc.so", mode=ctypes.RTLD_GLOBAL)'
    ''
    # We don't have residual packages to remove:
    # https://github.com/NVIDIA/TransformerEngine/blob/838345eba4fdd2a169dd9e087d39c30a360e684a/setup.py#L146-L148
    + ''
      substituteInPlace setup.py \
        --replace-fail \
          'uninstall_te_wheel_packages()' \
          ""
    ''
    # Replace the default /usr/local/cuda path with the one for cuda_cudart headers.
    # https://github.com/NVIDIA/TransformerEngine/blob/main/transformer_engine/common/util/cuda_runtime.cpp#L120-L124
    + ''
      substituteInPlace transformer_engine/common/util/cuda_runtime.cpp \
        --replace-fail \
          '{"", "/usr/local/cuda"}' \
          '{"", "${getOutput "include" cuda_cudart}/include"}'
    ''
    # Allow newer versions of flash-attention to be used.
    + ''
      substituteInPlace transformer_engine/pytorch/dot_product_attention/utils.py \
        --replace-fail \
          'max_version = PkgVersion("2.7.4.post1")' \
          'max_version = PkgVersion("2.99.99")'
    '';

  preConfigure = ''
    export CUDA_HOME="${getBin cuda_nvcc}"
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
