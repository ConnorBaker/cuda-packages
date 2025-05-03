{
  buildPythonPackage,
  codetr,
  config,
  cuda-python,
  cudaPackages,
  fetchFromGitHub,
  lib,
  mmcv,
  mmdet,
  mmengine,
  ninja,
  pkgs,
  pkgsBuildHost,
  pytest,
  python,
  runCommand,
  setuptools,
  tensorrt,
  torch-tensorrt,
  torch,
  torchvision,
}:
let
  inherit (cudaPackages)
    cuda_cudart
    cuda_nvcc
    flags
    libcublas
    libcusolver
    libcusparse
    ;

  codetr-deformable-attention = pkgs.callPackage ./codetr-deformable-attention.nix { };
in
# NOTE: Not building the C++ version because Torchvision isn't setup for that in Nixpkgs.
buildPythonPackage {
  __structuredAttrs = true;

  pname = "codetr";
  version = "1.0.2-unstable-2025-04-19";

  src = fetchFromGitHub {
    owner = "anenbergb";
    repo = "Co-DETR-TensorRT";
    rev = "fc2e7af3e6f79b4e1374dd015e7b4917f79d511b";
    hash = "sha256-A4kjNAoVOM6fGgOhtUdkSUByyoEg2g2YdSG9EYWjF+c=";
  };

  env = {
    CUDA_ARCH = flags.cmakeCudaArchitecturesString;
    # PyTorch just needs CUDA_HOME to contain NVCC so it can build CUDA code.
    CUDA_HOME = "${lib.getBin pkgsBuildHost.cudaPackages.cuda_nvcc}";
  };

  pyproject = true;

  build-system = [
    ninja
    setuptools
  ];

  nativeBuildInputs = [ cuda_nvcc ];

  postPatch = ''
    nixLog "removing runtime dependency on pytest from $PWD/setup.py"
    substituteInPlace "$PWD/setup.py" \
      --replace-fail \
        'install_requires=["numpy", "pytest"],' \
        'install_requires=["numpy"],'
  '';

  enableParallelBuilding = true;

  dependencies = [
    cuda-python
    mmcv
    mmdet
    mmengine
    tensorrt
    torch
    torch-tensorrt
    torchvision
  ];

  buildInputs = [
    cuda_cudart
    libcusparse
    libcublas
    libcusolver
  ];

  # TODO: Add tests.
  doCheck = false;

  postInstall = ''
    install -Dvm655 "${codetr-deformable-attention}/lib"/* "$out/${python.sitePackages}/codetr"
  '';

  passthru.tests = {
    pytest-csrc =
      runCommand "codetr-pytest-csrc"
        {
          __structuredAttrs = true;
          strictDeps = true;

          inherit (codetr) src version;

          nativeBuildInputs = [
            codetr
            pytest
            python
          ];

          requiredSystemFeatures = [ "cuda" ];
        }
        ''
          nixLog "copying codetr source to $PWD"
          cp -rv "$src"/* .
          nixLog "correcting permissions on codetr source"
          chmod -R u+w .
          nixLog "removing codetr python module to avoid conflicts"
          rm -rv codetr
          nixLog "removing non-csrc tests directory"
          rm -rv tests
          nixLog "running pytest"
          pytest \
            --verbose \
            --plugin-lib "${codetr}/${python.sitePackages}/codetr/libdeformable_attention_plugin.so" \
            csrc_tests
          nixLog "pytest finished"
          touch "$out"
        '';

    pytest =
      runCommand "codetr-pytest"
        {
          __structuredAttrs = true;
          strictDeps = true;

          inherit (codetr) src version;

          nativeBuildInputs = [
            codetr
            pytest
            python
          ];

          requiredSystemFeatures = [ "cuda" ];
        }
        ''
          nixLog "copying codetr source to $PWD"
          cp -rv "$src"/* .
          nixLog "correcting permissions on codetr source"
          chmod -R u+w .
          nixLog "removing codetr python module to avoid conflicts"
          rm -rv codetr
          nixLog "removing csrc tests directory"
          rm -rv csrc_tests
          nixLog "running pytest"
          pytest --verbose
          nixLog "pytest finished"
          touch "$out"
        '';
  };

  # Requires GPU
  # pythonImportsCheck = [ "codetr" ];

  meta = {
    description = "Co-DETR (Detection Transformer) compiled from PyTorch to NVIDIA TensorRT";
    homepage = "https://github.com/anenbergb/Co-DETR-TensorRT";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ connorbaker ];
    # TODO(@connorbaker): Avoid including cuda-python.meta.broken.
    broken = !config.cudaSupport || cuda-python.meta.broken;
  };
}
