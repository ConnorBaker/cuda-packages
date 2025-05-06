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
let
  version = "2.6.0";
in
buildPythonPackage {
  __structuredAttrs = true;

  pname = "torch-tensorrt";
  inherit version;

  src = fetchFromGitHub {
    owner = "pytorch";
    repo = "TensorRT";
    tag = "v${version}";
    hash = "sha256-DAdorB4PD7UvWJNiZq79QLiWR51OnFvhCLXSBnNkxnc=";
  };

  disabled = pythonOlder "3.7";

  pyproject = true;

  env = {
    RELEASE = "1";
    PYTHON_ONLY = "1"; # to avoid Bazel hellscape
    BUILD_VERSION = version;
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
        '__cuda_version__: "12.6"' \
        '__cuda_version__: "${cudaPackages.cudaMajorMinorVersion}"' \
      --replace-fail \
        '__tensorrt_version__: "10.7.0.post1"' \
        '__tensorrt_version__: "${cudaLib.utils.majorMinorPatch tensorrt.version}"'

    nixLog "patching $PWD/pyproject.toml"
    substituteInPlace "$PWD/pyproject.toml" \
      --replace-fail \
        "tensorrt-cu12>=10.7.0.post1,<10.8.0" \
        "tensorrt" \
      --replace-fail \
        "torch==2.6.0" \
        "torch" \
      --replace-fail \
        "pybind11==2.6.2" \
        "pybind11" \
      --replace-fail \
        '"tensorrt>=10.7.0.post1,<10.8.0",' \
        "" \
      --replace-fail \
        '"tensorrt-cu12-bindings>=10.7.0,<10.8.0",' \
        "" \
      --replace-fail \
        '"tensorrt-cu12-libs>=10.7.0,<10.8.0",' \
        ""
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
    # If the majorMinor version of the package is not the same as the majorMinor version of the
    # torch version, then the package is broken.
    broken = lib.versions.majorMinor torch.version != lib.versions.majorMinor version;
    license = lib.licenses.bsd3;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = with lib.maintainers; [ connorbaker ];
  };
}
