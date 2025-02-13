{
  cuda_cccl,
  cuda_cudart,
  cuda_nvcc,
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
  inherit (lib.attrsets)
    getBin
    getLib
    getOutput
    ;
  inherit (lib.lists) optionals;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "nccl";
  version = "2.25.1-1";

  # TODO: Build fails on CUDA 12.8 due to GCC 14 changes?
  # cuda12.8-nccl> /nix/store/2s2ra7dqy7xs1qqd9qxzj7rvizdnhvc2-gcc-14-20241116/include/c++/14-20241116/type_traits(1610): error: "__is_nothrow_new_constructible" is not a function or static data member
  # cuda12.8-nccl>       constexpr bool __is_nothrow_new_constructible
  # cuda12.8-nccl>                      ^
  # cuda12.8-nccl> /nix/store/2s2ra7dqy7xs1qqd9qxzj7rvizdnhvc2-gcc-14-20241116/include/c++/14-20241116/type_traits(1610): error: "constexpr" is not valid here
  # cuda12.8-nccl>       constexpr bool __is_nothrow_new_constructible
  # cuda12.8-nccl>       ^
  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "nccl";
    tag = "v${finalAttrs.version}";
    hash = "sha256-3snh0xdL9I5BYqdbqdl+noizJoI38mZRVOJChgEE1I8=";
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
        ' -ccbin $(CXX) ' \
        ' '

    nixLog "patching $PWD/makefiles/common.mk to replace -std=c++11 with -std=c++14"
    substituteInPlace ./makefiles/common.mk \
      --replace-fail \
        ' -std=c++11 ' \
        ' -std=c++14 '
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
