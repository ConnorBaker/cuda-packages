# NOTE: Though NCCL tests is called within the cudaPackages package set, we avoid passing in
# the names of dependencies from that package set directly to avoid evaluation errors
# in the case redistributable packages are not available.
{
  config,
  cuda_cccl,
  cuda_cudart,
  cuda_nvcc,
  fetchFromGitHub,
  gitUpdater,
  lib,
  mpi,
  mpiSupport ? false,
  nccl,
  stdenv,
  which,
}:
let
  inherit (lib.attrsets) getBin;
  inherit (lib.lists) optionals;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "nccl-tests";
  version = "2.13.12";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "nccl-tests";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4aHXIk5ydZsSARQw1T6Nx49FpQjwNEvVD6yfHoEGt8g=";
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
  ] ++ optionals mpiSupport [ mpi ];

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
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    license = licenses.bsd3;
    broken = !config.cudaSupport || (mpiSupport && mpi == null);
    maintainers = (with maintainers; [ jmillerpdt ]) ++ teams.cuda.members;
  };
})
