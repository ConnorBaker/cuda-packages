# NOTE: Though NCCL tests is called within the cudaPackages package set, we avoid passing in
# the names of dependencies from that package set directly to avoid evaluation errors
# in the case redistributable packages are not available.
{
  _cuda,
  config,
  cuda_cccl,
  cuda_cudart,
  cuda_nvcc,
  cudaNamePrefix,
  fetchFromGitHub,
  flags,
  gitUpdater,
  lib,
  mpi,
  mpiSupport ? false,
  nccl,
  stdenv,
  which,
}:
let
  inherit (_cuda.lib) _mkMetaBroken;
  inherit (lib) licenses maintainers teams;
  inherit (lib.attrsets) getBin;
  inherit (lib.lists) optionals;
in
stdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;

  # NOTE: Depends on the CUDA package set, so use cudaNamePrefix.
  name = "${cudaNamePrefix}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "nccl-tests";
  version = "2.14.1";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "nccl-tests";
    tag = "v${finalAttrs.version}";
    hash = "sha256-PntD5seMq7s0x4hOO/wBDQdElhKCY6mFrTf073mf7zM=";
  };

  postPatch = ''
    nixLog "patching $PWD/src/Makefile to remove NVIDIA's ccbin declaration"
    substituteInPlace ./src/Makefile \
      --replace-fail \
        '-ccbin $(CXX)' \
        ""

    nixLog "patching $PWD/src/Makefile to replace -std=c++11 with -std=c++14"
    substituteInPlace ./src/Makefile \
      --replace-fail \
        '-std=c++11' \
        '-std=c++14'
  '';

  nativeBuildInputs = [
    cuda_nvcc
    which
  ];

  buildInputs = [
    cuda_cccl # <nv/target>
    cuda_cudart
    nccl
  ]
  ++ optionals mpiSupport [ mpi ];

  makeFlags = [
    # NOTE: CUDA_HOME is expected to have the bin directory
    # TODO: This won't work with cross-compilation since cuda_nvcc will come from hostPackages by default (aka pkgs).
    "CUDA_HOME=${getBin cuda_nvcc}"
    "NCCL_HOME=${nccl}"
    "NVCC_GENCODE=${flags.gencodeString}"
  ]
  ++ optionals mpiSupport [ "MPI=1" ];

  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    install -Dm755 \
      $(find build -type f -executable) \
      "$out/bin"
    runHook postInstall
  '';

  passthru = {
    brokenAssertions = [
      {
        message = "mpi is non-null when mpiSupport is true";
        assertion = mpiSupport -> mpi != null;
      }
    ];

    updateScript = gitUpdater {
      inherit (finalAttrs) pname version;
      rev-prefix = "v";
    };
  };

  meta = {
    description = "Tests to check both the performance and the correctness of NVIDIA NCCL operations";
    homepage = "https://github.com/NVIDIA/nccl-tests";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    license = licenses.bsd3;
    broken = _mkMetaBroken (!(config.inHydra or false)) finalAttrs;
    maintainers = [ maintainers.jmillerpdt ] ++ teams.cuda.members;
  };
})
