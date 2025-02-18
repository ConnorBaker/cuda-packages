{
  addDriverRunpath,
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cuda_nvrtc,
  cudnn,
  fetchFromGitHub,
  flags,
  gtest,
  lib,
  libcublas,
  libcurand,
  ninja,
  python3,
  stdenv,
  # Options
  enableF16C ? false,
  enableTools ? false,
  # passthru.updateScript
  gitUpdater,
}:
let
  inherit (lib.asserts) assertMsg;
  inherit (lib.lists) optionals;
  inherit (lib.strings) cmakeBool cmakeFeature optionalString;
in
# TODO: This can also be packaged for Python!
# TODO: Tests.
assert assertMsg (!enableTools) "enableTools is not yet implemented";
stdenv.mkDerivation (finalAttrs: {
  pname = "cutlass";
  version = "3.6.0";

  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cutlass";
    tag = "v${finalAttrs.version}";
    hash = "sha256-FbMVqR4eZyum5w4Dj5qJgBPOS66sTem/qKZjYIK/7sg=";
  };

  # TODO: As a header-only library, we should make sure we have an `include` directory or similar which is not a
  # superset of the `out` (`bin`) or `dev` outputs (whih is what the multiple-outputs setup hook does by default).
  outputs = [ "out" ];

  nativeBuildInputs = [
    cuda_nvcc
    cmake
    ninja
    python3
  ];

  postPatch =
    # Prepend some commands to the CUDA.cmake file so it can find the CUDA libraries using CMake's FindCUDAToolkit
    # module. These target names are used throughout the project; I (@connorbaker) did not choose them.
    ''
      nixLog "patching CUDA.cmake to use FindCUDAToolkit"
      mv ./CUDA.cmake ./_CUDA_Append.cmake
      cat > ./_CUDA_Prepend.cmake <<'EOF'
      find_package(CUDAToolkit REQUIRED)
      foreach(_target cudart cuda_driver nvrtc)
        if (NOT TARGET CUDA::''${_target})
          message(FATAL_ERROR "''${_target} Not Found")
        endif()
        message(STATUS "''${_target} library: ''${CUDA_''${_target}_LIBRARY}")
        add_library(''${_target} ALIAS CUDA::''${_target})
      endforeach()
      EOF
      cat ./_CUDA_Prepend.cmake ./_CUDA_Append.cmake > ./CUDA.cmake
    '';

  enableParallelBuilding = true;

  buildInputs =
    [
      cuda_cudart
      cuda_nvrtc
      libcurand
    ]
    ++ optionals enableTools [
      cudnn
      libcublas
    ];

  cmakeFlags = [
    (cmakeFeature "CUTLASS_NVCC_ARCHS" flags.cmakeCudaArchitecturesString)
    (cmakeBool "CUTLASS_ENABLE_EXAMPLES" false)

    # Tests.
    (cmakeBool "CUTLASS_ENABLE_TESTS" finalAttrs.doCheck)
    (cmakeBool "CUTLASS_ENABLE_GTEST_UNIT_TESTS" finalAttrs.doCheck)
    (cmakeBool "CUTLASS_USE_SYSTEM_GOOGLETEST" true)

    # NOTE: Both CUDNN and CUBLAS can be used by the examples and the profiler. Since they are large dependencies, they
    #       are disabled by default.
    (cmakeBool "CUTLASS_ENABLE_TOOLS" enableTools)
    (cmakeBool "CUTLASS_ENABLE_CUBLAS" enableTools)
    (cmakeBool "CUTLASS_ENABLE_CUDNN" enableTools)

    # NOTE: Requires x86_64 and hardware support.
    (cmakeBool "CUTLASS_ENABLE_F16C" enableF16C)

    # TODO: Unity builds are supposed to reduce build time, but this seems to just reduce the number of tasks
    # generated?
    # NOTE: Good explanation of unity builds:
    #       https://www.methodpark.de/blog/how-to-speed-up-clang-tidy-with-unity-builds.
    (cmakeBool "CUTLASS_UNITY_BUILD_ENABLED" false)

    # NOTE: Can change the size of the executables
    (cmakeBool "CUTLASS_NVCC_EMBED_CUBIN" true)
    (cmakeBool "CUTLASS_NVCC_EMBED_PTX" true)
  ];

  doCheck = false;

  checkInputs = [ gtest ];

  # NOTE: Because the test cases immediately create and try to run the binaries, we don't have an opportunity
  # to patch them with autoAddDriverRunpath. To get around this, we add the driver runpath to the environment.
  preCheck = optionalString finalAttrs.doCheck ''
    export LD_LIBRARY_PATH="$(readlink -mnv "${addDriverRunpath.driverLink}/lib")"
  '';

  # This is *not* a derivation you want to build on a small machine.
  requiredSystemFeatures = optionals finalAttrs.doCheck [
    "big-parallel"
    "cuda"
  ];

  passthru = {
    updateScript = gitUpdater {
      inherit (finalAttrs) pname version;
      rev-prefix = "v";
    };
    # TODO:
    # tests.test = cutlass.overrideAttrs { doCheck = true; };
  };

  meta = with lib; {
    description = "CUDA Templates for Linear Algebra Subroutines";
    homepage = "https://github.com/NVIDIA/cutlass";
    license = licenses.asl20;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = (with maintainers; [ connorbaker ]) ++ teams.cuda.members;
  };
})
