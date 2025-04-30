{
  buildPythonPackage,
  fetchFromGitHub,
  lib,
  matplotlib,
  mmcv,
  ninja,
  pkgsBuildHost,
  pycocotools,
  pythonOlder,
  scipy,
  setuptools,
  shapely,
  terminaltables,
  torch,
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
    CUDA_HOME = lib.getBin pkgsBuildHost.cudaPackages.cuda_nvcc;
  };

  build-system = [
    ninja
    setuptools
  ];

  postPatch = ''
    nixLog "patching $PWD/mmdet/__init__.py to ease version constraint on mmcv"
    substituteInPlace "$PWD/mmdet/__init__.py" \
      --replace-fail \
        "mmcv_maximum_version = '2.2.0'" \
        "mmcv_maximum_version = '2.9.9'"
  '';

  dependencies = [
    matplotlib
    mmcv
    pycocotools
    scipy
    shapely
    terminaltables
    torch
    tqdm
  ];

  doCheck = false;

  pythonImportsCheck = [ "mmdet" ];

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
