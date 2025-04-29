{
  buildPythonPackage,
  cuda-bindings,
  cudaPackages,
  fetchFromGitHub,
  lib,
  pythonOlder,
  setuptools,
}:
let
  inherit (cudaPackages) cudaMajorMinorVersion;
  inherit (lib.attrsets) hasAttr;

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

    sourceRoot = "${finalAttrs.src.name}/cuda_python";

    pyproject = true;

    build-system = [ setuptools ];

    dependencies = [ cuda-bindings ];

    # NOTE: Tests are in the cuda-bindings package.
    doCheck = false;

    enableParallelBuilding = true;

    pythonImportsCheck = [ "cuda" ];

    meta = {
      description = "The home for accessing NVIDIA's CUDA platform from Python";
      homepage = "https://nvidia.github.io/cuda-python/";
      # TODO: Directory structure changed significantly between 12.2 and 12.6, have not updated patches yet.
      broken = cudaMajorMinorVersion == "12.2" || !(hasAttr cudaMajorMinorVersion versions);
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
