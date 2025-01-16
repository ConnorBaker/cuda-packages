{
  cuda_cccl,
  cuda_cudart,
  cuda_nvcc,
  cudaStdenv,
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
cudaStdenv.mkDerivation (finalAttrs: {
  pname = "nccl";
  version = "2.24.3-1";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "nccl";
    tag = "v${finalAttrs.version}";
    hash = "sha256-TpZDy9lae1zZ38IJid6h893gk8OFPaSCZoeegLoYq9Y=";
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

  buildInputs = [
    cuda_cccl
    cuda_cudart
    cuda_nvcc # crt/host_config.h
  ];

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
      (with maintainers; [
        mdaiter
        orivej
      ])
      ++ teams.cuda.members;
  };
})
