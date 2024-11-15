{
  backendStdenv,
  cuda_cccl ? null, # Only available from CUDA 12.0.
  cuda_cudart,
  cuda_nvcc,
  cudaAtLeast,
  fetchFromGitHub,
  flags,
  lib,
  python3,
  which,
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
  version = "2.23.4-1";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "nccl";
    rev = "refs/tags/v${finalAttrs.version}";
    hash = "sha256-DlMxlLO2F079fBkhORNPVN/ASYiVIRfLJw7bDoiClHw=";
  };

  outputs = [
    "out"
    "dev"
    "static"
  ];

  nativeBuildInputs = [
    cuda_nvcc
    python3
    which
  ];

  buildInputs =
    [
      cuda_cudart
      cuda_nvcc # crt/host_config.h
    ]
    # NOTE: CUDA versions in Nixpkgs only use a major and minor version. When we do comparisons
    # against other version, like below, it's important that we use the same format. Otherwise,
    # we'll get incorrect results.
    # For example, lib.versionAtLeast "12.0" "12.0.0" == false.
    ++ optionals (cudaAtLeast "12.0") [ cuda_cccl ];

  env.NIX_CFLAGS_COMPILE = toString [ "-Wno-unused-function" ];

  postPatch = ''
    patchShebangs ./src/device/generate.py
  '';

  # TODO: This would likely break under cross; need to delineate between build and host packages.
  makeFlags = [
    "CUDA_HOME=${getBin cuda_nvcc}"
    "CUDA_INC=${getOutput "include" cuda_cudart}/include"
    "CUDA_LIB=${getLib cuda_cudart}/lib"
    "NVCC_GENCODE=${flags.gencodeString}"
    "PREFIX=$(out)"
  ];

  enableParallelBuilding = true;

  postFixup = ''
    moveToOutput lib/libnccl_static.a "$static"
  '';

  passthru.updateScript = gitUpdater {
    inherit (finalAttrs) pname version;
    rev-prefix = "v";
  };

  meta = with lib; {
    description = "Multi-GPU and multi-node collective communication primitives for NVIDIA GPUs";
    homepage = "https://developer.nvidia.com/nccl";
    license = licenses.bsd3;
    platforms =
      optionals (!flags.isJetsonBuild) [
        "aarch64-linux"
      ]
      ++ [
        "x86_64-linux"
      ];
    badPlatforms = optionals flags.isJetsonBuild [ "aarch64-linux" ];
    maintainers =
      with maintainers;
      [
        mdaiter
        orivej
      ]
      ++ teams.cuda.members;
  };
})
