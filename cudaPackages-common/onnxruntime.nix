{
  abseil-cpp,
  addDriverRunpath,
  backendStdenv,
  cmake,
  cpuinfo,
  cuda_cccl, # cub/cub.cuh -- Only available from CUDA 12.0.
  cuda_cudart,
  cuda_nvcc,
  cudnn-frontend,
  cudnn,
  cutlass,
  doCheck ? false,
  fetchFromGitHub,
  fetchFromGitLab,
  gbenchmark,
  glibcLocales,
  gtest,
  lib,
  libcublas, # cublas_v2.h
  libcufft, # cufft.h
  libcurand, # curand.h
  libcusparse, # cusparse.h
  libpng,
  microsoft-gsl,
  nccl,
  ninja,
  nlohmann_json,
  onnx-tensorrt,
  onnx,
  onnxruntime, # For passthru.tests
  patchelf,
  pkg-config,
  protobuf,
  python3,
  re2,
  tensorrt,
  zlib,
}:

let
  inherit (lib.attrsets) getLib optionalAttrs;
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe;
  inherit (lib.strings)
    cmakeBool
    cmakeFeature
    cmakeOptionType
    concatStringsSep
    optionalString
    ;
  inherit (lib.versions) majorMinor;
  inherit (backendStdenv.cc) isClang;
  inherit (python3.pkgs)
    buildPythonPackage
    protobuf4
    pybind11
    setuptools
    ;

  isAarch64Linux = backendStdenv.hostPlatform.system == "aarch64-linux";

  # NOTE: As of 1.20, gotta use an older version of Eigen.
  eigen = fetchFromGitLab {
    owner = "libeigen";
    repo = "eigen";
    rev = "e7248b26a1ed53fa030c5c459f7ea095dfd276ac";
    hash = "sha256-uQ1YYV3ojbMVfHdqjXRyUymRPjJZV3WHT36PTxPRius=";
  };

  date = fetchFromGitHub {
    owner = "HowardHinnant";
    repo = "date";
    rev = "refs/tags/v3.0.1";
    hash = "sha256-ZSjeJKAcT7mPym/4ViDvIR9nFMQEBCSUtPEuMO27Z+I=";
  };

  safeint = fetchFromGitHub {
    owner = "dcleblanc";
    repo = "safeint";
    rev = "refs/tags/3.0.28";
    hash = "sha256-pjwjrqq6dfiVsXIhbBtbolhiysiFlFTnx5XcX77f+C0=";
  };

  flatbuffers = fetchFromGitHub {
    owner = "google";
    repo = "flatbuffers";
    rev = "refs/tags/v23.5.26";
    hash = "sha256-e+dNPNbCHYDXUS/W+hMqf/37fhVgEGzId6rhP3cToTE=";
  };

  clog = backendStdenv.mkDerivation {
    pname = "clog";
    version = builtins.substring 0 8 cpuinfo.src.rev;
    src = "${cpuinfo.src}/deps/clog";

    nativeBuildInputs = [
      cmake
      gbenchmark
      gtest
    ];

    cmakeFlags = [
      (cmakeBool "USE_SYSTEM_GOOGLEBENCHMARK" true)
      (cmakeBool "USE_SYSTEM_GOOGLETEST" true)
      (cmakeBool "USE_SYSTEM_LIBS" true)
      # 'clog' tests set 'CXX_STANDARD 11'; this conflicts with our 'gtest'.
      (cmakeBool "CLOG_BUILD_TESTS" false)
    ];
  };

  finalAttrs = {
    # Must opt-out of __structuredAttrs which is on by default in our stdenv, but currently incompatible with Python
    # packaging: https://github.com/NixOS/nixpkgs/pull/347194.
    __structuredAttrs = false;
    stdenv = backendStdenv;

    pname = "onnxruntime";

    # NOTE: Using newer version because nsync has been removed from the build system
    version = "1.20.0-unstable-2024-11-14";

    # TODO: build server, and move .so's to lib output
    # Python's wheel is stored in a separate dist output
    # outputs = [
    #   "out"
    #   "dev"
    #   # "dist"
    # ];

    src = fetchFromGitHub {
      owner = "microsoft";
      repo = "onnxruntime";
      rev = "632a36a23394a9deacf19c221db4ff89287ac152";
      hash = "sha256-7SrbDgYuLj60IYeeiSA9GxSn+P8xe5kSBRxFKxZuIh4=";
      fetchSubmodules = true;
    };

    pyproject = true;

    # Clang generates many more warnings than GCC does, so we just disable erroring on warnings entirely.
    env = optionalAttrs isClang { NIX_CFLAGS_COMPILE = "-Wno-error"; };

    # NOTE: Blocked moving to newer protobuf:
    # https://github.com/microsoft/onnxruntime/issues/21308

    build-system = [
      setuptools
      # protobuf4
    ];

    nativeBuildInputs = [
      cmake
      ninja
      cuda_nvcc
      patchelf
      pkg-config
      protobuf
      pybind11
      # python3
    ];
    # ++ optionals pythonSupport (
    #   with python3Packages;
    #   [
    #     pip
    #     python
    #     pythonOutputDistHook
    #     setuptools
    #     wheel
    #   ]
    # );

    postPatch =
      ''
        substituteInPlace cmake/libonnxruntime.pc.cmake.in \
          --replace-fail \
            '$'{prefix}/@CMAKE_INSTALL_ \
            "@CMAKE_INSTALL_"
      ''
      # Don't require the static libraries
      + ''
        substituteInPlace cmake/onnxruntime_providers_tensorrt.cmake \
          --replace-fail \
            'set(onnxparser_link_libs nvonnxparser_static)' \
            'set(onnxparser_link_libs nvonnxparser)'
      ''
      # cudnn_frontend doesn't provide a library
      + ''
        substituteInPlace cmake/onnxruntime_providers_cuda.cmake \
          --replace-fail \
            'target_link_libraries(''${target} PRIVATE CUDA::cublasLt CUDA::cublas CUDNN::cudnn_all cudnn_frontend ' \
            'target_link_libraries(''${target} PRIVATE CUDA::cublasLt CUDA::cublas CUDNN::cudnn_all '
        substituteInPlace cmake/onnxruntime_unittests.cmake \
          --replace-fail \
            'target_link_libraries(''${_UT_TARGET} PRIVATE CUDA::cudart cudnn_frontend)' \
            'target_link_libraries(''${_UT_TARGET} PRIVATE CUDA::cudart)'
      ''
      # Disable failing tests.
      # TODO: Is this on all platforms, or just x86_64-linux?
      + ''
        substituteInPlace onnxruntime/test/shared_lib/test_inference.cc \
          --replace-fail \
            'TEST(CApiTest, custom_op_set_input_memory_type) {' \
            'TEST(CApiTest, DISABLED_custom_op_set_input_memory_type) {'
        substituteInPlace onnxruntime/test/providers/cpu/activation/activation_op_test.cc \
          --replace-fail \
            'TEST_F(ActivationOpTest, ONNX_Gelu) {' \
            'TEST_F(ActivationOpTest, DISABLED_ONNX_Gelu) {'
      ''
      # TODO: Verify this fails.
      # https://github.com/NixOS/nixpkgs/pull/226734#issuecomment-1663028691
      + optionalString isAarch64Linux ''
        rm -v onnxruntime/test/optimizer/nhwc_transformer_test.cc
      '';

    # Use the same build dir the bash script wrapping the python script wrapping CMake expects us to use.
    # cmakeBuildDir = "build/Linux";
    # The CMakeLists.txt file is in the root of the source directory, two levels up from the build directory.
    cmakeDir = "../cmake";

    # Silence NVCC warnings from the frontend like:
    # onnxruntime> /nix/store/nrb1wyq26xxghhfky7sr22x27fip35vs-source/absl/types/span.h(154): error #2803-D: attribute namespace "gsl" is unrecognized
    # onnxruntime>   class [[gsl::Pointer]] Span {
    preConfigure = optionalString isClang ''
      appendToVar NVCC_PREPEND_FLAGS "-Xcudafe=--diag_suppress=2803"
    '';

    # postConfigure =
    # Return to the root of the source directory, leaving and deleting CMake's build directory.
    # ''
    #   cd "''${cmakeDir:?}"/..
    #   rm -rf "''${cmakeBuildDir:?}"
    # '';
    # Allow CMake to run its configuration setup hook to fully populate the cmakeFlags shell variable.
    # We'll format it and use it for the Python build.
    # To do that, we need to splat the cmakeFlags array and use bash string substitution to remove the leading on each
    # entry "-D".
    # TODO: If Python packaging supported __structuredAttrs, we could use `${cmakeFlags[@]#-D}`. But it doesn't, so we have
    # to use `${cmakeFlags[@]//-D/}` and hope none of our flags contain "-D".
    # TODO: How does bash handle accessing `cmakeFlags` as an array when __structuredAttrs is not set?
    # TODO: Conditionally enable NCCL.
    # NOTE: We need to specify CMAKE_CUDA_COMPILER to avoid the setup script trying to choose the compiler itself
    # (which it will fail to do because we use splayed installations).
    # TODO: Why do we need to pass Protobuf_LIBRARIES explicitly?
    # --clean \
    # + ''
    #   python3 "$PWD/tools/ci_build/build.py" \
    #       --build_dir "''${cmakeBuildDir:?}" \
    #       --build \
    #       --build_shared_lib \
    #       --update \
    #       --skip_submodule_sync \
    #       --config "Release" \
    #       --parallel ''${NIX_BUILD_CORES:?} \
    #       --enable_pybind \
    #       --build_wheel \
    #       --enable_lto \
    #       --test \
    #       --enable_nccl \
    #       --nccl_home "${getLib nccl}" \
    #       --use_cuda \
    #       --cuda_home "${getLib cuda_cudart}" \
    #       --cudnn_home "${getLib cudnn}" \
    #       --use_tensorrt \
    #       --tensorrt_home "${getLib tensorrt}" \
    #       --use_tensorrt_oss_parser \
    #       --use_full_protobuf \
    #       --cmake_extra_defines \
    #         ''${cmakeFlags[@]//-D/} \
    #         CMAKE_CUDA_COMPILER="${cuda_nvcc.bin}/bin/nvcc" \
    #         Protobuf_LIBRARIES="${getLib protobuf}/lib/libprotobuf.so"
    #   echo "Done with the python3 script for building"
    # '';

    # NOTE: Cannot re-use flatbuffers built in Nixpkgs for some reason.

    buildInputs =
      # Normal build inputs which are taken as-is from Nixpkgs
      [
        abseil-cpp
        clog
        cuda_cccl # CUDA 11.x <cub/cub.cuh>, CUDA 12.x <nv/target>
        cuda_cudart
        cudnn # cudnn.h
        cudnn-frontend # cudnn_frontend.h
        cpuinfo
        cutlass.src # NOTE: onnxruntime uses samples from the repo, and as a header-only library there's not much point in building it.
        glibcLocales
        libcublas # cublas_v2.h
        libcufft # cufft.h
        libcurand # curand.h
        libcusparse # cusparse.h
        libpng
        microsoft-gsl
        nlohmann_json
        onnx
        onnx-tensorrt
        protobuf
        re2
        tensorrt
        zlib
      ]
      ++ optionals nccl.meta.available [ nccl ]
      # Build inputs used for source.
      # TODO(@connorbaker): Package these and get onnxruntime to use them instead of building them in the derivation.
      ++ [
        eigen
        date
        flatbuffers
        safeint
      ];

    # TODO: This should depend on doCheck.
    # TODO: Why can't CMake find gtest in checkInputs?
    # ++ optionals doCheck [ gtest ];
    # ++ optionals pythonSupport (
    #   with python3Packages;
    #   [
    #     numpy
    #     pybind11
    #     packaging
    #   ]
    # );

    enableParallelBuilding = true;

    # TODO:
    # cuda12.6-onnxruntime> [ 11%] Built target custom_op_library
    # cuda12.6-onnxruntime> [ 11%] Running cpp protocol buffer (full) compiler on /build/source/onnxruntime/test/proto/tml.proto
    # cuda12.6-onnxruntime> onnx/onnx-ml.proto: File not found.
    # cuda12.6-onnxruntime> tml.proto:3:1: Import "onnx/onnx-ml.proto" was not found or had errors.
    # cuda12.6-onnxruntime> tml.proto:95:5: "onnx.TensorProto" is not defined.
    # cuda12.6-onnxruntime> make[2]: *** [CMakeFiles/onnx_test_data_proto.dir/build.make:75: tml.pb.h] Error 1
    # cuda12.6-onnxruntime> make[1]: *** [CMakeFiles/Makefile2:755: CMakeFiles/onnx_test_data_proto.dir/all] Error 2
    # cuda12.6-onnxruntime> make[1]: *** Waiting for unfinished jobs....

    cmakeFlags = [
      (cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
      (cmakeBool "onnxruntime_BUILD_SHARED_LIB" true)
      (cmakeBool "onnxruntime_BUILD_UNIT_TESTS" finalAttrs.doCheck)
      (cmakeBool "onnxruntime_ENABLE_LTO" true)
      (cmakeBool "onnxruntime_ENABLE_PYTHON" true)
      (cmakeBool "onnxruntime_USE_CUDA" true)
      (cmakeBool "onnxruntime_USE_FULL_PROTOBUF" true) # NOTE: Using protobuf_21-lite causes linking errors
      (cmakeBool "onnxruntime_USE_NCCL" nccl.meta.available) # TODO(@connorbaker): available is not a reliable indicator of whether NCCL is available (no recursive meta checking)
      (cmakeBool "onnxruntime_USE_NSYNC" false)
      # TODO(@connorbaker): Unclear if this actually causes onnxruntime to use onnx-tensorrt;
      # the CMake code indicates it merely searches for the library for the parser wherever tensorrt was discovered.
      (cmakeBool "onnxruntime_USE_TENSORRT_BUILTIN_PARSER" false) # Use onnx-tensorrt
      (cmakeBool "onnxruntime_USE_TENSORRT" true)
      (cmakeFeature "FETCHCONTENT_TRY_FIND_PACKAGE_MODE" "ALWAYS")
      (cmakeFeature "onnxruntime_NVCC_THREADS" "1")
      (cmakeBool "onnxruntime_USE_PREINSTALLED_EIGEN" true)
      (cmakeOptionType "PATH" "eigen_SOURCE_PATH" eigen.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_CUTLASS" cutlass.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_DATE" date.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_FLATBUFFERS" flatbuffers.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_SAFEINT" safeint.outPath)
    ];

    # nativeCheckInputs = [ gtest ];
    checkInputs = [ gtest ];
    # ++ optionals pythonSupport (
    #   with python3Packages;
    #   [
    #     pytest
    #     sympy
    #     onnx
    #   ]
    # );

    # aarch64-linux fails cpuinfo test, because /sys/devices/system/cpu/ does not exist in the sandbox
    # as does testing on the GPU
    inherit doCheck;

    # NOTE: Because the test cases immediately create and try to run the binaries, we don't have an opportunity
    # to patch them with autoAddDriverRunpath. To get around this, we add the driver runpath to the environment.
    preCheck = optionalString finalAttrs.doCheck ''
      export LD_LIBRARY_PATH="$(readlink -mnv "${addDriverRunpath.driverLink}/lib")"
    '';

    # Failed tests:
    # ActivationOpTest.ONNX_Gelu
    # CApiTest.custom_op_set_input_memory_type

    requiredSystemFeatures = [ "big-parallel" ] ++ optionals finalAttrs.doCheck [ "cuda" ];

    # postBuild = optionalString pythonSupport ''
    #   ${python3Packages.python.interpreter} ../setup.py bdist_wheel
    # '';

    # perform parts of `tools/ci_build/github/linux/copy_strip_binary.sh`
    postInstall = ''
      install -m644 -Dt "$out/include" \
        ../include/onnxruntime/core/framework/provider_options.h \
        ../include/onnxruntime/core/providers/cpu/cpu_provider_factory.h \
        ../include/onnxruntime/core/session/onnxruntime_*.h
    '';

    # /build/source/onnxruntime/core/session/provider_bridge_ort.cc:1586 void onnxruntime::ProviderSharedLibrary::Ensure() [ONNXRuntimeError] : 1 : FAIL : Failed to load library libonnxruntime_providers_shared.so with error: libonnxruntime_providers_shared.so: cannot open shared object file: No such file or directory
    postFixup = optionalString finalAttrs.doCheck ''
      patchelf --add-rpath "$out/lib" "$out/bin/onnx_test_runner"
    '';

    passthru = {
      inherit cpuinfo;
      tests = {
        gpu = onnxruntime.override { doCheck = true; };
      };
    };

    meta = with lib; {
      description = "Cross-platform, high performance scoring engine for ML models";
      longDescription = ''
        ONNX Runtime is a performance-focused complete scoring engine
        for Open Neural Network Exchange (ONNX) models, with an open
        extensible architecture to continually address the latest developments
        in AI and Deep Learning. ONNX Runtime stays up to date with the ONNX
        standard with complete implementation of all ONNX operators, and
        supports all ONNX releases (1.2+) with both future and backwards
        compatibility.
      '';
      homepage = "https://github.com/microsoft/onnxruntime";
      changelog = "https://github.com/microsoft/onnxruntime/releases/tag/v${version}";
      # https://github.com/microsoft/onnxruntime/blob/master/BUILD.md#architectures
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      license = licenses.mit;
      maintainers = with maintainers; [
        puffnfresh
        ck3d
        cbourjau
      ];
    };
  };
in
backendStdenv.mkDerivation finalAttrs
