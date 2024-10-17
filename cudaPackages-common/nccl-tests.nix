# NOTE: Though NCCL tests is called within the cudaPackages package set, we avoid passing in
# the names of dependencies from that package set directly to avoid evaluation errors
# in the case redistributable packages are not available.
{
  backendStdenv,
  cuda_cccl ? null, # Only available from CUDA 12.0.
  cuda_cudart,
  cuda_nvcc,
  cudaAtLeast,
  cudaMajorMinorVersion,
  fetchFromGitHub,
  gitUpdater,
  lib,
  mpi,
  mpiSupport ? false,
  nccl,
  pkgs,
  which,
}:
let
  inherit (lib.attrsets) getBin;
  inherit (lib.lists) optionals;
in
backendStdenv.mkDerivation (finalAttrs: {
  name = "cuda${cudaMajorMinorVersion}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "nccl-tests";
  version = "2.13.9";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "nccl-tests";
    rev = "v${finalAttrs.version}";
    hash = "sha256-QYuMBPhvHHVo2ku14jD1CVINLPW0cyiXJkXxb77IxbE=";
  };

  strictDeps = true;

  nativeBuildInputs = [
    cuda_nvcc
    which
  ];

  buildInputs =
    [
      cuda_cudart
      nccl
    ]
    ++ optionals (cudaAtLeast "12.0") [
      cuda_cccl # <nv/target>
    ]
    ++ optionals mpiSupport [ mpi ];

  makeFlags = [
    # NOTE: CUDA_HOME is expected to have the bin directory
    # TODO: This won't work with cross-compilation since cuda_nvcc will come from hostPackages by default (aka pkgs).
    "CUDA_HOME=${getBin cuda_nvcc}"
    "NCCL_HOME=${nccl}"
  ] ++ optionals mpiSupport [ "MPI=1" ];

  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    install -Dm755 \
      $(find build -type f -executable) \
      "$out/bin"
    runHook postInstall
  '';

  passthru.updateScript = gitUpdater {
    inherit (finalAttrs) pname version;
    rev-prefix = "v";
  };

  meta = with lib; {
    description = "Tests to check both the performance and the correctness of NVIDIA NCCL operations";
    homepage = "https://github.com/NVIDIA/nccl-tests";
    platforms = platforms.linux;
    license = licenses.bsd3;
    broken = !pkgs.config.cudaSupport || (mpiSupport && mpi == null);
    maintainers = with maintainers; [ jmillerpdt ] ++ teams.cuda.members;
  };
})
