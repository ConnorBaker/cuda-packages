{
  buildPythonPackage,
  fetchFromGitHub,
  lib,
  setuptools,
}:
buildPythonPackage {
  __structuredAttrs = true;

  pname = "nvdlfw_inspect";
  version = "0.1";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "nvidia-dlfw-inspect";
    tag = "v0.1";
    hash = "sha256-nKVJmjfY14g0xz69OdCeVkFu2pAXOyE4U3JwqiYbnwI=";
  };

  pyproject = true;

  build-system = [ setuptools ];

  enableParallelBuilding = true;

  # TODO: Add tests.
  doCheck = false;

  pythonImportsCheck = [ "nvdlfw_inspect" ];

  meta = {
    description = "Debug convergence issues and testing new algorithms and recipes for training LLMs using Nvidia libraries";
    homepage = "https://github.com/NVIDIA/nvidia-dlfw-inspect?tab=readme-ov-file";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ connorbaker ];
  };
}
