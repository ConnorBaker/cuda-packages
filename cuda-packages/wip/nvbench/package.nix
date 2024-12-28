{
  addDriverRunpath,
  autoAddDriverRunpath,
  cmake,
  cpm-cmake,
  cuda_cccl,
  cuda_cudart,
  cuda_cupti,
  cuda_nvcc,
  cuda_nvml_dev,
  cudaStdenv,
  fetchFromGitHub,
  fetchurl,
  flags,
  fmt,
  git,
  gitUpdater,
  lib,
  writeTextFile,
}:
let
  inherit (lib.lists) optionals;
  inherit (lib.strings)
    cmakeBool
    concatStringsSep
    cmakeOptionType
    cmakeFeature
    optionalString
    ;

  # TODO: These tests complain about missing libraries which are available when requiredSystemFeatures includes "cuda"
  ignoredTests = [
    "nvbench.test.cmake.test_export.build_tree"
    "nvbench.test.cmake.test_export.install_tree"
  ];
in
cudaStdenv.mkDerivation (finalAttrs: {
  pname = "nvbench";
  version = "0-unstable-2024-11-15";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "nvbench";
    rev = "f52aa4b0aaef6dcbc044b39f9e09df639341b1ae";
    hash = "sha256-K3mhV2hY6k9jetcwURPQAsuNh58L3iFvgDzbURd7gzc=";
  };

  # TODO: Figure out how to package the nightmare of rapids-cmake.
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = "";

  # outputs = [
  #   "out"
  #   "dev"
  #   "lib"
  # ];

  nativeBuildInputs = [
    autoAddDriverRunpath
    cmake
    cuda_nvcc
    cpm-cmake
    git
  ];

  enableParallelBuilding = true;

  buildInputs = [
    cuda_cccl
    cuda_cudart
    cuda_cupti
    cuda_nvml_dev
    fmt
  ];

  # Correct the assumptions about CUPTI's location.
  # NOTE: `dev` and `include` are different outputs; `include` contains the actual headers, while `dev` uses
  # nix-support/* files to manage adding dependencies.
  postPatch = ''
    echo "Patching cmake/NVBenchCUPTI.cmake to fix paths"
    substituteInPlace cmake/NVBenchCUPTI.cmake \
      --replace-fail \
        '"''${nvbench_cupti_root}/include"' \
        '"${cuda_cupti.include}/include"'
  '';

  cmakeFlags = [
    # (cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
    (cmakeFeature "FETCHCONTENT_TRY_FIND_PACKAGE_MODE" "ALWAYS")

    (cmakeBool "CPM_USE_LOCAL_PACKAGES" true)

    (cmakeBool "NVBench_ENABLE_NVML" true)
    (cmakeBool "NVBench_ENABLE_CUPTI" true)
    (cmakeBool "NVBench_ENABLE_TESTING" finalAttrs.doCheckGpu)
    # NOTE: NVBench_ENABLE_HEADER_TESTING can be done independently of GPU availability.
    (cmakeBool "NVBench_ENABLE_HEADER_TESTING" finalAttrs.doCheck)
    # NOTE: We do not use NVBench_ENABLE_DEVICE_TESTING because it requires a GPU with locked clocks.
    (cmakeBool "NVBench_ENABLE_DEVICE_TESTING" false)

    (cmakeBool "NVBench_ENABLE_EXAMPLES" true)

    (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" flags.cmakeCudaArchitecturesString)

    # Pass arguments to the ctest executable when run through the CMake test target.
    # Nixpkgs uses `make test` so this is necessary unless we want a custom checkPhase.
    # For more on the options available to ctest, see:
    # https://cmake.org/cmake/help/book/mastering-cmake/chapter/Testing%20With%20CMake%20and%20CTest.html#testing-using-ctest
    # (cmakeFeature "CMAKE_CTEST_ARGUMENTS" (
    #   concatStringsSep ";" [
    #     # Run only tests with the CUDA label
    #     "-L"
    #     "CUDA"
    #     # Exclude ignored tests
    #     "-E"
    #     "'${concatStringsSep "|" ignoredTests}'"
    #   ]
    # ))
  ];

  doCheck = false;
  doCheckGpu = false;

  requiredSystemFeatures = optionals finalAttrs.doCheckGpu [ "cuda" ];

  # NOTE: Because the test cases immediately create and try to run the binaries, we don't have an opportunity
  # to patch them with autoAddDriverRunpath. To get around this, we add the driver runpath to the environment.
  preCheck = optionalString finalAttrs.doCheckGpu ''
    export LD_LIBRARY_PATH="$(readlink -mnv "${addDriverRunpath.driverLink}/lib")"
  '';

  passthru = {
    updateScript = gitUpdater {
      inherit (finalAttrs) pname version;
      rev-prefix = "v";
    };
    tests.withGpu = finalAttrs.finalPackage.overrideAttrs { doCheckGpu = true; };
    inherit cpm-cmake;
  };

  meta = with lib; {
    description = "CUDA Kernel Benchmarking Library";
    homepage = "https://github.com/NVIDIA/nvbench";
    license = licenses.asl20;
    broken = !(finalAttrs.doCheckGpu -> finalAttrs.doCheck);
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = (with maintainers; [ connorbaker ]) ++ teams.cuda.members;
  };
})
