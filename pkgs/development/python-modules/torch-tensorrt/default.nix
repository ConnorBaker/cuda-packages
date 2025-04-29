{
  buildPythonPackage,
  cffi,
  cudaLib,
  cudaPackages,
  fetchFromGitHub,
  future,
  lib,
  numpy,
  pybind11,
  pythonOlder,
  setuptools,
  tensorrt,
  torch,
  typing-extensions,
}:
buildPythonPackage {
  __structuredAttrs = true;

  pname = "torch-tensorrt";
  version = "2.5.0";

  src = fetchFromGitHub {
    owner = "pytorch";
    repo = "TensorRT";
    tag = "v2.5.0";
    hash = "sha256-L5rk3EEPloNNAeYEjwX7cOeTId6XW/Y54mmwHf4vzeY=";
  };

  disabled = pythonOlder "3.7";

  pyproject = true;

  env = {
    RELEASE = "1";
    PYTHON_ONLY = "1"; # to avoid Bazel hellscape
    BUILD_VERSION = "2.5.0";
  };

  build-system = [
    pybind11
    setuptools
  ];

  postPatch = ''
    nixLog "patching $PWD/setup.py"
    substituteInPlace "$PWD/setup.py" \
      --replace-fail \
      'def get_root_dir() -> Path:' \
    '
    def get_root_dir() -> Path:
        return Path(".")
    '

    nixLog "patching $PWD/dev_dep_versions.yml"
    substituteInPlace "$PWD/dev_dep_versions.yml" \
      --replace-fail \
        '__cuda_version__: "12.4"' \
        '__cuda_version__: "${cudaPackages.cudaMajorMinorVersion}"' \
      --replace-fail \
        '__tensorrt_version__: "10.3.0"' \
        '__tensorrt_version__: "${cudaLib.utils.majorMinorPatch tensorrt.version}"'

    nixLog "patching $PWD/pyproject.toml"
    substituteInPlace "$PWD/pyproject.toml" \
      --replace-fail \
        "tensorrt-cu12==10.3.0" \
        "tensorrt" \
      --replace-fail \
        '"tensorrt-cu12-bindings==10.3.0",' \
        "" \
      --replace-fail \
        '"tensorrt-cu12-libs==10.3.0",' \
        "" \
      --replace-fail \
        "pybind11==2.6.2" \
        "pybind11"
  '';

  dependencies = [
    cffi
    future
    numpy
    tensorrt
    torch
    typing-extensions
  ];

  doCheck = false;

  # TODO: Requires GPU.
  # pythonImportsCheck = [ "torch_tensorrt" ];

  # TODO: Tests to evaluate whether the package works.

  meta = {
    description = "PyTorch/TorchScript/FX compiler for NVIDIA GPUs using TensorRT";
    homepage = "https://pytorch.org/TensorRT/";
    license = lib.licenses.bsd3;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = with lib.maintainers; [ connorbaker ];
  };
}
