{
  cmake,
  cuda_cudart,
  cuda_cccl,
  cuda_nvcc,
  cuda_nvrtc,
  cuda_nvtx,
  cuda_profiler_api,
  cudaNamePrefix,
  cudaPackagesConfig,
  fetchFromGitHub,
  flags,
  lib,
  libcublas,
  libcufft,
  libcurand,
  libcusolver,
  libcusparse,
  libnpp,
  libnvjitlink,
  libnvjpeg,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;

  name = "${cudaNamePrefix}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "tests-cuda-samples";
  version = "12.8";

  # We should be able to use samples from the latest version of CUDA
  # on most of the CUDA package sets we have.
  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cuda-samples";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Ba0Fi0v/sQ+1iJ4mslgyIAE+oK5KO0lMoTQCC91vpiA=";
  };

  prePatch =
    # https://github.com/NVIDIA/cuda-samples/issues/333
    ''
      nixLog "removing sample 0_Introduction/UnifiedMemoryStreams which requires OpenMP support for CUDA"
      substituteInPlace \
        "$NIX_BUILD_TOP/$sourceRoot/Samples/0_Introduction/CMakeLists.txt" \
        --replace-fail \
          'add_subdirectory(UnifiedMemoryStreams)' \
          '# add_subdirectory(UnifiedMemoryStreams)'
    ''
    # This sample tries to use a relative path, which doesn't work for our splayed installation.
    + ''
      nixLog "patching sample 0_Introduction/matrixMul_nvrtc"
      substituteInPlace \
        "$NIX_BUILD_TOP/$sourceRoot/Samples/0_Introduction/matrixMul_nvrtc/CMakeLists.txt" \
        --replace-fail \
          "\''${CUDAToolkit_BIN_DIR}/../include/cooperative_groups" \
          "${lib.getOutput "include" cuda_cudart}/include/cooperative_groups" \
        --replace-fail \
          "\''${CUDAToolkit_BIN_DIR}/../include/nv" \
          "${lib.getOutput "include" cuda_cccl}/include/nv" \
        --replace-fail \
          "\''${CUDAToolkit_BIN_DIR}/../include/cuda" \
          "${lib.getOutput "include" cuda_cccl}/include/cuda"
    ''
    # These three samples give undefined references, like
    # nvlink error   : Undefined reference to '__cudaCDP2Free' in 'CMakeFiles/cdpBezierTessellation.dir/BezierLineCDP.cu.o'
    # nvlink error   : Undefined reference to '__cudaCDP2Malloc' in 'CMakeFiles/cdpBezierTessellation.dir/BezierLineCDP.cu.o'
    # nvlink error   : Undefined reference to '__cudaCDP2GetParameterBufferV2' in 'CMakeFiles/cdpBezierTessellation.dir/BezierLineCDP.cu.o'
    # nvlink error   : Undefined reference to '__cudaCDP2LaunchDeviceV2' in 'CMakeFiles/cdpBezierTessellation.dir/BezierLineCDP.cu.o'
    + ''
      for sample in cdp{AdvancedQuicksort,BezierTessellation,Quadtree,SimplePrint,SimpleQuicksort}; do
        nixLog "removing sample 3_CUDA_Features/$sample which fails to link"
        substituteInPlace \
          "$NIX_BUILD_TOP/$sourceRoot/Samples/3_CUDA_Features/CMakeLists.txt" \
          --replace-fail \
            "add_subdirectory($sample)" \
            "# add_subdirectory($sample)"
      done
      unset -v sample
    ''
    # For some reason this sample requires a static library, which we don't propagate by default due to size.
    + ''
      nixLog "patching sample 4_CUDA_Libraries/simpleCUFFT_callback to use dynamic library"
      substituteInPlace \
        "$NIX_BUILD_TOP/$sourceRoot/Samples/4_CUDA_Libraries/simpleCUFFT_callback/CMakeLists.txt" \
        --replace-fail \
          'CUDA::cufft_static' \
          'CUDA::cufft'
    ''
    # Patch to use the correct path to libnvJitLink.so
    + ''
      nixLog "patching sample 4_CUDA_Libraries/jitLto to use correct path to libnvJitLink.so"
      substituteInPlace \
        "$NIX_BUILD_TOP/$sourceRoot/Samples/4_CUDA_Libraries/jitLto/CMakeLists.txt" \
        --replace-fail \
          "\''${CUDAToolkit_LIBRARY_DIR}/libnvJitLink.so" \
          "${lib.getLib libnvjitlink}/lib/libnvJitLink.so"
    ''
    # NVVM samples require a specific build of LLVM, which is a hassle.
    + ''
      nixLog "removing samples 7_libNVVM which require a specific build of LLVM"
      substituteInPlace \
        "$NIX_BUILD_TOP/$sourceRoot/Samples/CMakeLists.txt" \
        --replace-fail \
          'add_subdirectory(7_libNVVM)' \
          '# add_subdirectory(7_libNVVM)'
    ''
    # Don't use hard-coded CUDA architectures
    + ''
      nixLog "patching CMakeLists.txt to use provided CUDA architectures"
      local path=""
      while IFS= read -r -d $'\0' path; do
        nixLog "removing CMAKE_CUDA_ARCHITECTURES declaration from $path"
        substituteInPlace \
          "$path" \
          --replace-fail \
            'set(CMAKE_CUDA_ARCHITECTURES' \
            '# set(CMAKE_CUDA_ARCHITECTURES'
      done < <(grep --files-with-matches --null "set(CMAKE_CUDA_ARCHITECTURES" --recursive "$NIX_BUILD_TOP/$sourceRoot")
      unset -v path
    '';

  nativeBuildInputs = [
    cmake
    cuda_nvcc
  ];

  buildInputs = [
    cuda_cccl
    cuda_cudart
    cuda_nvrtc
    cuda_nvtx
    cuda_profiler_api
    libcublas
    libcufft
    libcurand
    libcusolver
    libcusparse
    libnpp
    libnvjitlink
    libnvjpeg
  ];

  # TODO(@connorbaker):
  # For some reason, using the combined find command doesn't delete directories:
  # find "$PWD/Samples" \
  #     \( -type d -name CMakeFiles \) \
  #     -o \( -type f -name cmake_install.cmake \) \
  #     -o \( -type f -name Makefile \) \
  #     -exec rm -rf {} +
  installPhase = ''
    runHook preInstall

    pushd "$NIX_BUILD_TOP/$sourceRoot/''${cmakeBuildDir:?}" >/dev/null

    nixLog "deleting CMake related files"

    find "$PWD/Samples" -type d -name CMakeFiles -exec rm -rf {} +
    find "$PWD/Samples" -type f -name cmake_install.cmake -exec rm -rf {} +
    find "$PWD/Samples" -type f -name Makefile -exec rm -rf {} +

    nixLog "copying $PWD/Samples to $out/"
    mkdir -p "$out"
    cp -rv "$PWD/Samples"/* "$out/"

    popd >/dev/null

    runHook postInstall
  '';

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" flags.cmakeCudaArchitecturesString)
    (lib.cmakeBool "BUILD_TEGRA" cudaPackagesConfig.hasJetsonCudaCapability)
  ];
})
