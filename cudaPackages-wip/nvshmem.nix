{
  backendStdenv,
  cmake,
  cuda_cudart,
  cuda_nvcc,
  flags,
  fetchzip,
  gdrcopy,
  lib,
  mpi,
  pkg-config,
  nccl,
  ucx,
}:
let
  inherit (lib.attrsets) getBin;
  inherit (lib.lists) optionals;
  inherit (lib.strings)
    cmakeBool
    cmakeFeature
    cmakeOptionType
    ;
  # TODO: Add to cuda-lib or upstream.
  cmakePath = cmakeOptionType "PATH";
in
backendStdenv.mkDerivation (finalAttrs: {
  pname = "nvshmem";
  version = "3.0.6";

  src = fetchzip {
    url = "https://developer.download.nvidia.com/compute/redist/nvshmem/3.0.6/source/nvshmem_src_3.0.6-4.txz";
    hash = "sha256-BP1p0UTW3ZKiP8GQLNySOIImAjb5Va0XNsNTRg4L/P4=";
  };

  outputs = [
    "out"
  ];

  nativeBuildInputs = [
    cmake
    cuda_nvcc
    mpi # TODO(@connorbaker): mpi can't be found unless in nativeBuildInputs.
    pkg-config
  ];

  cmakeFlags = [
    (cmakePath "NVSHMEM_PREFIX" (builtins.placeholder "out"))
    (cmakePath "CUDA_HOME" "${getBin cuda_nvcc}")
    # GDRCOPY_HOME?
    (cmakeBool "NVSHMEM_MPI_SUPPORT" true)
    (cmakeBool "NVSHMEM_UCX_SUPPORT" true)
    (cmakeBool "NVSHMEM_USE_GDRCOPY" gdrcopy.meta.available)
    (cmakeBool "NVSHMEM_USE_NCCL" nccl.meta.available)
    # Their CMakeLists.txt ignores what we've set for CUDAARCHS so we have to set it explicitly.
    (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" flags.cmakeCudaArchitecturesString)
  ];

  buildInputs = [
    cuda_cudart
    ucx
  ] ++ optionals gdrcopy.meta.available [ gdrcopy ] ++ optionals nccl.meta.available [ nccl ];

  enableParallelBuilding = true;

  meta = with lib; {
    description = "A parallel programming interface, based on OpenSHMEM, that provides efficient and scalable communication for NVIDIA GPU clusters";
    longDescription = ''
      NVSHMEM is a parallel programming interface based on OpenSHMEM
      that provides efficient and scalable communication for NVIDIA GPU
      clusters. NVSHMEM creates a global address space for data that spans
      the memory of multiple GPUs and can be accessed with fine-grained
      GPU-initiated operations, CPU-initiated operations, and operations
      on CUDA(R) streams.
    '';
    homepage = "https://developer.nvidia.com/nvshmem";
    license = licenses.nvidiaCuda; # TODO(@connorbaker): No license distributed with the source?
    platforms = platforms.linux;
    badPlatforms = optionals flags.isJetsonBuild [ "aarch64-linux" ];
    maintainers =
      (with maintainers; [
        connorbaker
      ])
      ++ teams.cuda.members;
  };
})
