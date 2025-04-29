{
  buildPythonPackage,
  cmake,
  config,
  cudaPackages,
  einops,
  fetchFromGitHub,
  lib,
  ninja,
  psutil,
  setuptools,
  torch,
  wheel,
}:
let
  inherit (cudaPackages)
    cuda_cudart
    cuda_nvcc
    cutlass
    flags
    ;
  inherit (lib.attrsets) getOutput;
  inherit (lib.lists) any;
  inherit (lib.strings) concatStringsSep versionOlder;
in
buildPythonPackage {
  __structuredAttrs = true;

  pname = "flash_attn";
  version = "2.7.4-unstable-2025-04-08";

  src = fetchFromGitHub {
    owner = "Dao-AILab";
    repo = "flash-attention";
    rev = "2afa43cdab1e173f81408c37a7457aadf3bda895";
    hash = "sha256-abgaYtmq+WzW88V2F+PGx0RK8SSs8Wp3qqM/P3L+9cM=";
  };

  pyproject = true;

  postPatch = ''
    mkdir -p csrc/cutlass
    cp -r "${getOutput "include" cutlass}"/include csrc/cutlass/include
    substituteInPlace setup.py \
      --replace-fail \
        '+ cc_flag' \
        '+ ["${concatStringsSep ''","'' flags.gencode}"]'
  '';

  preConfigure = ''
    export BUILD_TARGET=cuda
    export FORCE_BUILD=TRUE
  '';

  enableParallelBuilding = true;

  build-system = [
    cmake
    ninja
    psutil
    setuptools
    wheel
  ];

  nativeBuildInputs = [ cuda_nvcc ];

  dontUseCmakeConfigure = true;

  dependencies = [
    einops
    torch
  ];

  buildInputs = [ cuda_cudart ];

  # TODO: Add tests.
  doCheck = false;

  pythonImportsCheck = [ "flash_attn_interface" ];

  # This is *not* a derivation you want to build on a small machine.
  requiredSystemFeatures = [ "big-parallel" ];

  meta = {
    description = "Fast and memory-efficient exact attention";
    homepage = "https://github.com/Dao-AILab/flash-attention";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ connorbaker ];
    broken =
      !config.cudaSupport || any (capability: versionOlder capability "8.0") flags.cudaCapabilities;
  };
}
