{
  buildPythonPackage,
  cffi,
  cudaLib,
  cudaPackages,
  fetchFromGitHub,
  future,
  lib,
  numpy,
  ninja,
  pybind11,
  mmcv,
  pythonOlder,
  setuptools,
  tensorrt,
  torch,
  typing-extensions,
  matplotlib,
  pycocotools,
  scipy,
  shapely,
  terminaltables,
  tqdm,
}:
buildPythonPackage {
  __structuredAttrs = true;

  pname = "mmdet";
  version = "3.3.0";

  src = fetchFromGitHub {
    owner = "open-mmlab";
    repo = "mmdetection";
    tag = "v3.3.0";
    hash = "sha256-0Dvd5wMREb+XBSZt1GH5FyWAidlfoVwuoF6espzWziI=";
  };

  disabled = pythonOlder "3.7";

  pyproject = true;

  env = {
    FORCE_CUDA = "1";
  };

  build-system = [
    ninja
    setuptools
  ];

  # postPatch = ''
  #   nixLog "patching $PWD/setup.py"
  #   substituteInPlace "$PWD/setup.py" \
  #     --replace-fail \
  #     'def get_root_dir() -> Path:' \
  #   '
  #   def get_root_dir() -> Path:
  #       return Path(".")
  #   '

  #   nixLog "patching $PWD/dev_dep_versions.yml"
  #   substituteInPlace "$PWD/dev_dep_versions.yml" \
  #     --replace-fail \
  #       '__cuda_version__: "12.4"' \
  #       '__cuda_version__: "${cudaPackages.cudaMajorMinorVersion}"' \
  #     --replace-fail \
  #       '__tensorrt_version__: "10.3.0"' \
  #       '__tensorrt_version__: "${cudaLib.utils.majorMinorPatch tensorrt.version}"'

  #   nixLog "patching $PWD/pyproject.toml"
  #   substituteInPlace "$PWD/pyproject.toml" \
  #     --replace-fail \
  #       "tensorrt-cu12==10.3.0" \
  #       "tensorrt" \
  #     --replace-fail \
  #       '"tensorrt-cu12-bindings==10.3.0",' \
  #       "" \
  #     --replace-fail \
  #       '"tensorrt-cu12-libs==10.3.0",' \
  #       "" \
  #     --replace-fail \
  #       "pybind11==2.6.2" \
  #       "pybind11"
  # '';

  dependencies = [
    # cffi
    # future
    # numpy
    # tensorrt
    torch
    # typing-extensions
    mmcv
    matplotlib
    pycocotools
    scipy
    shapely
    terminaltables
    tqdm
  ];

  doCheck = false;

  # TODO: Requires GPU.
  # pythonImportsCheck = [ "mmdet" ];

  # TODO: Tests to evaluate whether the package works.

  meta = {
    description = "OpenMMLab Detection Toolbox and Benchmark";
    homepage = "https://github.com/open-mmlab/mmdetection";
    license = lib.licenses.asl20;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = with lib.maintainers; [ connorbaker ];
  };
}
