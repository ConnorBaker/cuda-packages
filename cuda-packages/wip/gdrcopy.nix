{
  backendStdenv,
  cuda_cudart,
  cuda_nvcc,
  fetchFromGitHub,
  flags,
  lib,
  # passthru.updateScript
  gitUpdater,
}:
let
  inherit (lib.attrsets)
    getBin
    getLib
    getOutput
    ;
  inherit (lib.lists) optionals;
in
backendStdenv.mkDerivation (finalAttrs: {
  pname = "nccl";
  version = "2.4.2";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "gdrcopy";
    rev = "refs/tags/v${finalAttrs.version}";
    hash = "sha256-digpn+f08GKYF94hCOl4k9hbvEqHbCVYC5YJdz8SwSU=";
  };

  outputs = [
    "out"
  ];

  nativeBuildInputs = [
    cuda_nvcc
  ];

  # TODO(@connorbaker): Need to add case for SBSA
  # https://github.com/NVIDIA/gdrcopy/blob/7e3797ff381844b46fa120b67c6bbcc4e89ab741/config_arch#L32C11-L32C14
  # TODO(@connorbaker): Need to patch where it looks for NVIDIA kernel modules:
  # https://github.com/NVIDIA/gdrcopy/blob/7e3797ff381844b46fa120b67c6bbcc4e89ab741/src/gdrdrv/Makefile#L21
  postPatch = ''
    substituteInPlace ./Makefile \
      --replace-fail \
        'GDRAPI_ARCH := $(shell ./config_arch)' \
        'GDRAPI_ARCH := X86'
  '';

  # TODO: This would likely break under cross; need to delineate between build and host packages.
  makeFlags = [
    "CUDA_HOME=${getBin cuda_nvcc}"
    "CUDA_INC=${getOutput "include" cuda_cudart}/include"
    "CUDA_LIB=${getLib cuda_cudart}/lib"
    "NVCC_GENCODE=${flags.gencodeString}"
    "PREFIX=$(out)"
  ];

  buildInputs = [
    cuda_cudart
  ];

  enableParallelBuilding = true;

  passthru.updateScript = gitUpdater {
    inherit (finalAttrs) pname version;
    rev-prefix = "v";
  };

  meta = with lib; {
    description = "Multi-GPU and multi-node collective communication primitives for NVIDIA GPUs";
    homepage = "https://developer.nvidia.com/nccl";
    license = licenses.mit;
    platforms = platforms.linux;
    badPlatforms = optionals flags.isJetsonBuild [ "aarch64-linux" ];
    maintainers =
      (with maintainers; [
        connorbaker
      ])
      ++ teams.cuda.members;
  };
})
