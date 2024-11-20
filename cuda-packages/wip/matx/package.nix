# NOTE: Though NCCL is called within the cudaPackages package set, we avoid passing in
# the names of dependencies from that package set directly to avoid evaluation errors
# in the case redistributable packages are not available.
{
  # autoAddDriverRunpath,
  backendStdenv,
  callPackage,
  cmake,
  cpm-cmake,
  cuda_cudart,
  cuda_nvcc,
  cudaOlder,
  fmt,
  cuquantum,
  cutlass,
  fetchFromGitHub,
  flags,
  gitUpdater,
  gtest,
  lib,
  libcublas,
  libcutensor,
  libcurand,
  libcufft,
  libcusolver,
  ninja,
  python3,
  which,
}:
let
  inherit (lib) teams maintainers licenses;
  inherit (lib.attrsets) mapAttrs;
  inherit (lib.strings) cmakeBool cmakeFeature cmakeOptionType;
  inherit (lib.trivial) const flip;

  inherit (python3.pkgs)
    pybind11
    numpy
    ;

  cccl = callPackage ./cccl.nix { }; # TODO: Use in-tree cccl.
  nvbench = callPackage ./nvbench.nix { };

in
backendStdenv.mkDerivation (finalAttrs: {
  pname = "MatX";
  version = "0.9.0-unstable-2024-11-15";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "MatX";
    rev = "57713392128fcc3686b1aa4070c34ad78023f790";
    hash = "sha256-zcE7gX7QNCrlGyn9dHrxQCHy2BV7PYTO6N0VQr282yg=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    cuda_nvcc
    python3
    pybind11
    numpy
  ];

  buildInputs = [
    cuda_cudart
    libcutensor
    cuquantum # cutensorNet
    cpm-cmake
  ];

  checkInputs = [
    gtest
    fmt
    libcublas
    libcufft
    libcusolver
    libcurand
  ];

  # The cache keys are hashes of the parameteres CPM uses to download and unpack
  # from a source. Just update them when the build fails.
  postUnpack = ''
    echo "Creating MatX CPM cache"
    mkdir -p .cache/CPM
    pushd .cache/CPM
    export CPM_SOURCE_CACHE="$PWD"

    echo "Copying CCCL"
    mkdir -p cccl
    cp -r "${cccl}" cccl/1cec94fe8decf060a1cd7172b9bc0dc953c52bbd

    echo "Copying NVBench"
    mkdir -p nvbench
    cp -r "${nvbench}" nvbench/8dac2ff49f1fdb2eb2d8814abf78d5ebbd1015ed

    popd
    chmod -R u+w -- "$CPM_SOURCE_CACHE"
  '';

  postPatch =
    # Set a CMake variable which requires shell interpolation
    ''
      appendToVar cmakeFlags "${
        cmakeOptionType "PATH" "rapids-cmake-dir"
          "$NIX_BUILD_TOP/$sourceRoot/cmake/rapids-cmake/rapids-cmake"
      }"
    ''
    # Use a newer version of CPM.cmake
    + ''
      substituteInPlace cmake/rapids-cmake/rapids-cmake/cpm/detail/download.cmake \
        --replace-fail \
          'message(FATAL_ERROR "CPM.cmake hash mismatch' \
          'message(WARNING "CPM.cmake hash mismatch'
    ''
    # Patch erroneous invocation of rapids_cpm_find:
    # cuda12.6-MatX>   find_package called with invalid argument "2.7.0-rc2"
    # That's not a valid version number.
    + ''
      substituteInPlace cmake/rapids-cmake/rapids-cmake/cpm/cccl.cmake \
        --replace-fail \
          'rapids_cpm_find(CCCL ''${version} ''${ARGN}' \
          'rapids_cpm_find(CCCL "2.7.0.0" ''${ARGN}'
    '';

  # TODO: This should be handled by setup hooks in rapids-cmake.
  # cmakeFlags = rapids-cmake.passthru.data.cmakeFlags ++ [
  cmakeFlags = [
    (cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
    (cmakeFeature "FETCHCONTENT_TRY_FIND_PACKAGE_MODE" "ALWAYS")

    (cmakeBool "CPM_USE_LOCAL_PACKAGES" true)

    (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" flags.cmakeCudaArchitecturesString)

    (cmakeBool "MATX_BUILD_EXAMPLES" finalAttrs.doCheck)
    (cmakeBool "MATX_BUILD_TESTS" finalAttrs.doCheck)
    (cmakeBool "MATX_BUILD_BENCHMARKS" finalAttrs.doCheck)
    (cmakeBool "MATX_NVTX_FLAGS" true)
    (cmakeBool "MATX_BUILD_DOCS" false)
    (cmakeBool "MATX_BUILD_32_BIT" false)
    (cmakeBool "MATX_MULTI_GPU" false) # Requires Nvshmem?
    (cmakeBool "MATX_EN_VISUALIZATION" false) # TODO: Revisit
    # (cmakeBool "MATX_EN_CUTLASS" false) # TODO: CUTLASS support is removed in main?
    (cmakeBool "MATX_EN_CUTENSOR" true)
    (cmakeBool "MATX_EN_FILEIO" true)
    (cmakeBool "MATX_EN_NVPL" false) # TODO: Revisit for ARM support
    # option(MATX_EN_X86_FFTW OFF "Enable x86 FFTW support") # TODO: Revisit for x86
    (cmakeBool "MATX_DISABLE_CUB_CACHE" true) # TODO: Why?

    (cmakeBool "MATX_EN_PYBIND11" finalAttrs.doCheck) # TODO: For unit tests and benchmarks
  ];

  # propagatedBuildInputs = pythonDeps;

  enableParallelBuilding = true;

  doCheck = true;

  passthru = {
    updateScript = gitUpdater {
      inherit (finalAttrs) pname version;
      rev-prefix = "v";
    };
  };

  meta = {
    description = "An efficient C++17 GPU numerical computing library with Python-like syntax";
    homepage = "https://nvidia.github.io/MatX";
    broken = cudaOlder "11.4";
    license = licenses.bsd3;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = (with maintainers; [ connorbaker ]) ++ teams.cuda.members;
  };
})
