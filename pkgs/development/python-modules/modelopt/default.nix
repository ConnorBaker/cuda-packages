{
  buildPythonPackage,
  cudaPackages,
  cython,
  fetchFromGitHub,
  lib,
  modelopt-core,
  ninja,
  numpy,
  pulp,
  pydantic,
  pynvml,
  regex,
  rich,
  safetensors,
  scipy,
  setuptools-scm,
  setuptools,
  torch,
  torchprofile,
  torchvision,
  tqdm,
}:
buildPythonPackage {
  __structuredAttrs = true;

  pname = "modelopt";
  version = "0.27.1";

  pyproject = true;

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "TensorRT-Model-Optimizer";
    tag = "0.27.1";
    hash = "sha256-sy8VwZfVObjg6ftEKCgiy40zWZihloWfhnBP/kVSAwc=";
  };

  build-system = [
    cython
    setuptools
    setuptools-scm
  ];

  dependencies = [
    modelopt-core
    ninja
    numpy
    pydantic
    rich
    scipy
    tqdm
  ];

  doCheck = true;

  pythonImportsCheck = [ "modelopt" ];

  # TODO(@connorbaker): This derivation should contain Python tests for modelopt.

  passthru.optional-dependencies = {
    #   "onnx": [
    #     "cppimport",
    #     "cupy-cuda12x; platform_machine != 'aarch64' and platform_system != 'Darwin'",
    #     "onnx",
    #     "onnxconverter-common",
    #     "onnx-graphsurgeon",
    #     # Onnxruntime 1.20+ is not supported on Python 3.9
    #     "onnxruntime~=1.18.1 ; python_version < '3.10'",
    #     "onnxruntime~=1.20.1 ; python_version >= '3.10' and (platform_machine == 'aarch64' or platform_system == 'Darwin')",  # noqa: E501
    #     "onnxruntime-gpu~=1.20.1 ; python_version >= '3.10' and platform_machine != 'aarch64' and platform_system != 'Darwin'",  # noqa: E501
    #     "onnxsim ; python_version < '3.12' and platform_machine != 'aarch64'",
    # ],
    torch = [
      pulp
      pynvml
      regex
      safetensors
      torch
      torchprofile
      torchvision
    ];
  };

  meta = {
    description = "A c++ wrapper for the cudnn backend API";
    homepage = "https://github.com/NVIDIA/TensorRT-Model-Optimizer";
    license = lib.licenses.asl20;
    broken = cudaPackages.cudaStdenv.hasJetsonCudaCapability;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = (with lib.maintainers; [ connorbaker ]) ++ lib.teams.cuda.members;
  };
}
