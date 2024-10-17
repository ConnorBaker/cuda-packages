# NOTE: Though NCCL is called within the cudaPackages package set, we avoid passing in
# the names of dependencies from that package set directly to avoid evaluation errors
# in the case redistributable packages are not available.
{
  autoAddDriverRunpath,
  backendStdenv,
  cuda_cccl ? null, # Only available from CUDA 12.0.
  cuda_cudart,
  cuda_nvcc,
  cudaAtLeast,
  cudaMajorMinorVersion,
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
    attrValues
    getBin
    getLib
    getOutput
    ;
  inherit (lib.lists) any optionals;
  inherit (lib.trivial) id;
in
backendStdenv.mkDerivation (finalAttrs: {
  name = "cuda${cudaMajorMinorVersion}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "nccl";
  version = "2.21.5-1";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "nccl";
    rev = "v${finalAttrs.version}";
    hash = "sha256-IF2tILwW8XnzSmfn7N1CO7jXL95gUp02guIW5n1eaig=";
  };

  __structuredAttrs = true;
  strictDeps = true;

  outputs = [
    "out"
    "dev"
    "static"
  ];

  # badPlatformsConditions :: AttrSet Bool
  # Sets `meta.badPlatforms = meta.platforms` if any of the conditions are true.
  # Example: Broken on a specific architecture when some condition is met (like targeting Jetson).
  badPlatformsConditions = {
    # Samples are built around the CUDA Toolkit, which is not available for
    # aarch64. Check for both CUDA version and platform.
    "Platform is unsupported" = flags.isJetsonBuild;
  };

  nativeBuildInputs = [
    autoAddDriverRunpath
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
    platforms = platforms.linux;
    broken = any id (attrValues (finalAttrs.brokenConditions or { }));
    badPlatforms =
      let
        isBadPlatform = lists.any trivial.id (attrsets.attrValues finalAttrs.badPlatformsConditions);
      in
      lists.optionals isBadPlatform finalAttrs.meta.platforms;
    maintainers =
      with maintainers;
      [
        mdaiter
        orivej
      ]
      ++ teams.cuda.members;
  };
})
