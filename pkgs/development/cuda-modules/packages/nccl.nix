{
  cuda_cccl,
  cuda_cudart,
  cuda_nvcc,
  cudaStdenv,
  cudaNamePrefix,
  fetchFromGitHub,
  flags,
  lib,
  python3,
  stdenv,
  which,
  # passthru.updateScript
  gitUpdater,
}:
let
  inherit (cudaStdenv) hasJetsonCudaCapability;
  inherit (lib.attrsets)
    getBin
    getLib
    getOutput
    ;
  inherit (lib.lists) optionals;
in
stdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;

  # NOTE: Depends on the CUDA package set, so use cudaNamePrefix.
  name = "${cudaNamePrefix}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "nccl";
  version = "2.26.2-1";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "nccl";
    tag = "v${finalAttrs.version}";
    hash = "sha256-iLEuru3gaNLcAdH4V8VIv3gjdTGjgb2/Mr5UKOh69N4=";
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
    (getOutput "include" cuda_nvcc)
    cuda_cccl
    cuda_cudart
  ];

  env.NIX_CFLAGS_COMPILE = toString [ "-Wno-unused-function" ];

  postPatch = ''
    patchShebangs ./src/device/generate.py

    nixLog "patching $PWD/makefiles/common.mk to remove NVIDIA's ccbin declaration"
    substituteInPlace ./makefiles/common.mk \
      --replace-fail \
        '-ccbin $(CXX)' \
        ""

    nixLog "patching $PWD/makefiles/common.mk to replace -std=c++11 with -std=c++14"
    substituteInPlace ./makefiles/common.mk \
      --replace-fail \
        '-std=c++11' \
        '-std=c++14'
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
      optionals (!hasJetsonCudaCapability) [
        "aarch64-linux"
      ]
      ++ [
        "x86_64-linux"
      ];
    badPlatforms = optionals hasJetsonCudaCapability [ "aarch64-linux" ];
    maintainers =
      (with maintainers; [
        mdaiter
        orivej
      ])
      ++ teams.cuda.members;
  };
})
