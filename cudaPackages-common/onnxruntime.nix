{
  backendStdenv,
  cmake,
  cuda_cccl ? null, # cub/cub.cuh -- Only available from CUDA 12.0.
  cuda_cudart,
  cuda_nvcc,
  cudaAtLeast,
  cudnn,
  cudaMajorMinorVersion,
  fetchFromGitHub,
  fetchFromGitLab,
  flags,
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
  nlohmann_json,
  srcOnly,
  nsync,
  onnx,
  onnx-tensorrt,
  onnxruntime, # For passthru.tests
  pkg-config,
  python3,
  re2,
  tensorrt,
  zlib,
  abseil-cpp,
  protobuf_21,
}:

let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.lists) optionals;
  inherit (lib.strings)
    cmakeBool
    cmakeFeature
    cmakeOptionType
    optionalString
    ;
  inherit (lib.versions) majorMinor;
  inherit (backendStdenv.cc) isClang;
  inherit (python3.pkgs) buildPythonPackage flatbuffers setuptools;

  isAarch64Linux = backendStdenv.hostPlatform.system == "aarch64-linux";

  version = "1.19.2";

  eigen = fetchFromGitLab {
    owner = "libeigen";
    repo = "eigen";
    rev = "e7248b26a1ed53fa030c5c459f7ea095dfd276ac";
    hash = "sha256-uQ1YYV3ojbMVfHdqjXRyUymRPjJZV3WHT36PTxPRius=";
  };

  cutlass = srcOnly {
    strictDeps = true;
    name = "cutlass-source-3.5.0-patched";
    src = fetchFromGitHub {
      owner = "NVIDIA";
      repo = "cutlass";
      rev = "refs/tags/v3.5.0";
      hash = "sha256-D/s7eYsa5l/mfx73tE4mnFcTQdYqGmXa9d9TCryw4e4=";
    };
    patches = [ "${onnxruntime.src}/cmake/patches/cutlass/cutlass_3.5.0.patch" ];
  };

  date = fetchFromGitHub {
    owner = "HowardHinnant";
    repo = "date";
    rev = "refs/tags/v3.0.1";
    hash = "sha256-ZSjeJKAcT7mPym/4ViDvIR9nFMQEBCSUtPEuMO27Z+I=";
  };

  mp11 = fetchFromGitHub {
    owner = "boostorg";
    repo = "mp11";
    rev = "refs/tags/boost-1.82.0";
    hash = "sha256-cLPvjkf2Au+B19PJNrUkTW/VPxybi1MpPxnIl4oo4/o=";
  };

  safeint = fetchFromGitHub {
    owner = "dcleblanc";
    repo = "safeint";
    rev = "refs/tags/3.0.28";
    hash = "sha256-PK1ce4C0uCR4TzLFg+elZdSk5DdPCRhhwT3LvEwWnPU=";
  };

  # flatbuffers = fetchFromGitHub {
  #   owner = "google";
  #   repo = "flatbuffers";
  #   rev = "refs/tags/v23.5.26";
  #   hash = "sha256-e+dNPNbCHYDXUS/W+hMqf/37fhVgEGzId6rhP3cToTE=";
  # };

  cpuinfoRev = "ca678952a9a8eaa6de112d154e8e104b22f9ab3f";

  cpuinfo = srcOnly {
    strictDeps = true;
    name = "cpuinfo-source-${builtins.substring 0 8 cpuinfoRev}-patched";
    src = fetchFromGitHub {
      owner = "pytorch";
      repo = "cpuinfo";
      rev = cpuinfoRev;
      hash = "sha256-UKy9TIiO/UJ5w+qLRlMd085CX2qtdVH2W3rtxB5r6MY=";
    };
    patches = [
      "${onnxruntime.src}/cmake/patches/cpuinfo/9bb12d342fd9479679d505d93a478a6f9cd50a47.patch"
    ];
  };

  # NOTE: Versions beyond 1.16.3 expect cpuinfo to be available as a library.
  clog = backendStdenv.mkDerivation {
    strictDeps = true;

    pname = "clog";
    version = builtins.substring 0 8 cpuinfoRev;
    src = "${cpuinfo}/deps/clog";

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
in
buildPythonPackage {
  strictDeps = true;
  stdenv = backendStdenv;

  name = "cuda${cudaMajorMinorVersion}-onnxruntime-${version}";
  pname = "onnxruntime";
  inherit version;

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
    rev = "refs/tags/v${version}";
    hash = "sha256-LLTPDvdWdK+2yo7uRVzjEQOEmc2ISEQ1Hp2SZSYSpSU=";
    fetchSubmodules = true;
  };

  pyproject = true;

  # Clang generates many more warnings than GCC does, so we just disable erroring on warnings entirely.
  env = optionalAttrs isClang { NIX_CFLAGS_COMPILE = "-Wno-error"; };

  # prePatch = ''
  #   python3 ./setup.py bdist_wheel --help
  #   exit 1
  # '';

  build-system = [
    setuptools
  ];

  nativeBuildInputs = [
    cmake
    cuda_nvcc
    pkg-config
    # protobuf_21
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
      substituteInPlace "cmake/onnxruntime_providers_tensorrt.cmake" \
        --replace-fail \
          'set(onnxparser_link_libs nvonnxparser_static)' \
          'set(onnxparser_link_libs nvonnxparser)'
    ''
    # https://github.com/NixOS/nixpkgs/pull/226734#issuecomment-1663028691
    + optionalString isAarch64Linux ''
      rm -v onnxruntime/test/optimizer/nhwc_transformer_test.cc
    '';

  # Silence NVCC warnings from the frontend like:
  # onnxruntime> /nix/store/nrb1wyq26xxghhfky7sr22x27fip35vs-source/absl/types/span.h(154): error #2803-D: attribute namespace "gsl" is unrecognized
  # onnxruntime>   class [[gsl::Pointer]] Span {
  preConfigure =
    optionalString isClang ''
      appendToVar NVCC_PREPEND_FLAGS "-Xcudafe=--diag_suppress=2803"
    ''
    + ''
      echo "Running the build script"
      # python3 "$PWD/tools/ci_build/build.py" --help
      # exit 1
      python3 "$PWD/tools/ci_build/build.py" \
        --build_dir "$PWD/build/Linux" \
        --build \
        --update \
        --skip_submodule_sync \
        --config "Release" \
        --clean \
        --enable_pybind \
        --build_wheel \
        --test \
        --use_cuda \
        --cuda_home "${cuda_cudart.lib}" \
        --cudnn_home "${cudnn.lib}" \
        --use_tensorrt \
        --use_tensorrt_oss_parser \
        --use_full_protobuf \
        --enable_lto \
        --cmake_extra_defines
    '';

  dependencies = [
    flatbuffers
  ];

  buildInputs =
    [
      clog
      cuda_cudart
      cudnn # cudnn.h
      glibcLocales
      libcublas # cublas_v2.h
      libcufft # cufft.h
      libcurand # curand.h
      libcusparse # cusparse.h
      libpng
      microsoft-gsl
      nlohmann_json
      onnx-tensorrt
      tensorrt
      zlib
    ]
    ++ optionals (cudaAtLeast "12.0") [
      cuda_cccl # <nv/target>
    ]
    ++ optionals nccl.meta.available [ nccl ];
  # ++ optionals pythonSupport (
  #   with python3Packages;
  #   [
  #     numpy
  #     pybind11
  #     packaging
  #   ]
  # );

  enableParallelBuilding = true;

  cmakeDir = "../cmake";

  cmakeFlags =
    [
      (cmakeBool "ABSL_ENABLE_INSTALL" true)
      (cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
      (cmakeBool "FETCHCONTENT_QUIET" false)
      (cmakeBool "onnxruntime_BUILD_SHARED_LIB" true)
      (cmakeBool "onnxruntime_BUILD_UNIT_TESTS" true)
      (cmakeBool "onnxruntime_ENABLE_LTO" true)
      # (cmakeBool "onnxruntime_ENABLE_PYTHON" pythonSupport)
      (cmakeBool "onnxruntime_ENABLE_PYTHON" false)
      (cmakeBool "onnxruntime_USE_CUDA" true)
      (cmakeBool "onnxruntime_USE_FULL_PROTOBUF" true) # NOTE: Using protobuf_21-lite causes linking errors
      (cmakeBool "onnxruntime_USE_NCCL" nccl.meta.available)
      # TODO(@connorbaker): Unclear if this actually causes onnxruntime to use onnx-tensorrt;
      # the CMake code indicates it merely searches for the library for the parser wherever tensorrt was discovered.
      (cmakeBool "onnxruntime_USE_TENSORRT_BUILTIN_PARSER" false) # Use onnx-tensorrt
      (cmakeBool "onnxruntime_USE_TENSORRT" true)
      (cmakeBool "onnxruntime_USE_PREINSTALLED_EIGEN" true)
      (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" flags.cmakeCudaArchitecturesString)
      (cmakeFeature "FETCHCONTENT_TRY_FIND_PACKAGE_MODE" "ALWAYS")
      (cmakeFeature "onnxruntime_NVCC_THREADS" "1")
      (cmakeOptionType "PATH" "eigen_SOURCE_PATH" eigen.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_ABSEIL_CPP" abseil-cpp.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_CUTLASS" cutlass.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_DATE" date.outPath)
      # (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_FLATBUFFERS" flatbuffers.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_GOOGLE_NSYNC" nsync.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_MP11" mp11.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_ONNX" onnx.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_RE2" re2.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_SAFEINT" safeint.outPath)

      # The inclusion of CMake files sets targets that onnxruntime needs defined for CMake configuration to succeed.
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_PYTORCH_CPUINFO" cpuinfo.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_GOOGLETEST" gtest.src.outPath)
    ]
    # Onnx flags
    # TODO: Reuse Onnx build since we've got both the C++ libraries and the Python bindings
    ++ [
      # (cmakeBool "BUILD_ONNX_PYTHON" pythonSupport)
      (cmakeBool "BUILD_ONNX_PYTHON" false)
      (cmakeBool "BUILD_SHARED_LIBS" true)
      (cmakeBool "ONNX_BUILD_BENCHMARKS" false)
      (cmakeBool "ONNX_BUILD_TESTS" true)
      (cmakeBool "ONNX_USE_PROTOBUF_SHARED_LIBS" true)
      (cmakeBool "ONNX_VERIFY_PROTO3" true)
      (cmakeFeature "ONNX_NAMESPACE" "onnx")
    ]
    ++ optionals (majorMinor onnx.version == "1.16") [
      (cmakeBool "ONNX_BUILD_SHARED_LIBS" true)
      (cmakeBool "ONNX_GEN_PB_TYPE_STUBS" false)
    ];

  nativeCheckInputs = [ gtest ];
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
  doCheck = false;

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

  # passthru = {
  #   tests = optionalAttrs pythonSupport { python = python3Packages.onnxruntime; };
  # };

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
    platforms = platforms.linux;
    license = licenses.mit;
    maintainers = with maintainers; [
      puffnfresh
      ck3d
      cbourjau
    ];
  };
}
