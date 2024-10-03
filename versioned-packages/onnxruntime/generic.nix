{
  backendStdenv,
  cmake,
  cpuinfo,
  cuda_cccl, # cub/cub.cuh
  cuda_cudart,
  cuda_nvcc,
  cudaMajorMinorVersion,
  fetchzip,
  fetchFromGitHub,
  flags,
  flatbuffers,
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
  nsync,
  onnx,
  onnx-tensorrt,
  pkg-config,
  python3Packages,
  pythonSupport ? false,
  re2,
  tensorrt,
  zlib,
  # Package overrides
  version,
  hash,
  # Packages
  abseil-cpp,
  protobuf,
  # Sources
  cutlass,
}:

let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.lists) optionals;
  inherit (lib.strings)
    cmakeBool
    cmakeFeature
    cmakeOptionType
    optionalString
    versionOlder
    ;
  inherit (lib.versions) majorMinor;
  inherit (backendStdenv.cc) isClang;
  isAarch64Linux = backendStdenv.hostPlatform.system == "aarch64-linux";

  inherit (tensorrt.passthru) cudnn;

  # TODO(@connorbaker): Fetch the source for onnxruntime here, so we can apply patches kept in-tree to different dependencies by wrapping them with
  # srcOnly: https://github.com/microsoft/onnxruntime/tree/main/cmake/patches.

  eigen = fetchzip {
    url = "https://gitlab.com/libeigen/eigen/-/archive/e7248b26a1ed53fa030c5c459f7ea095dfd276ac/eigen-e7248b26a1ed53fa030c5c459f7ea095dfd276ac.zip";
    hash = "sha256-uQ1YYV3ojbMVfHdqjXRyUymRPjJZV3WHT36PTxPRius=";
  };

  howard-hinnant-date = fetchFromGitHub {
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

  pytorch_clog = backendStdenv.mkDerivation {
    strictDeps = true;

    pname = "clog";
    version = cpuinfo.version;
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
in
backendStdenv.mkDerivation (finalAttrs: {
  strictDeps = true;

  name = "cuda${cudaMajorMinorVersion}-${finalAttrs.pname}-${finalAttrs.version}";
  pname = "onnxruntime";
  inherit version;

  # TODO: build server, and move .so's to lib output
  # Python's wheel is stored in a separate dist output
  outputs = [
    "out"
    "dev"
  ] ++ optionals pythonSupport [ "dist" ];

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "onnxruntime";
    rev = "refs/tags/v${finalAttrs.version}";
    inherit hash;
    fetchSubmodules = true;
  };

  env = optionalAttrs isClang {
    NIX_CFLAGS_COMPILE = toString [
      "-Wno-error=deprecated-declarations"
      "-Wno-error=deprecated-pragma"
      "-Wno-error=unused-but-set-variable"
    ];
  };

  nativeBuildInputs =
    [
      cmake
      pkg-config
      python3Packages.python
      protobuf
    ]
    ++ optionals pythonSupport (
      with python3Packages;
      [
        pip
        python
        pythonOutputDistHook
        setuptools
        wheel
      ]
    )
    ++ [
      cuda_nvcc
    ];

  patches =
    [
      # If you stumble on these patches trying to update onnxruntime, check
      # `git blame` and ping the introducers.

      # Context: we want the upstream to
      # - always try find_package first (FIND_PACKAGE_ARGS),
      # - use MakeAvailable instead of the low-level Populate,
      # - use Eigen3::Eigen as the target name (as declared by libeigen/eigen).
      # ./0001-eigen-allow-dependency-injection.patch
    ]
    ++ optionals (versionOlder version "1.19") [
      # Incorporate a patch that has landed upstream which exposes new
      # 'abseil-cpp' libraries & modifies the 're2' CMakeLists to fix a
      # configuration error that around missing 'gmock' exports.
      ./update-re2.patch
    ];
  # ++ optionals cudaSupport [
  #   # We apply the referenced 1064.patch ourselves to our nix dependency.
  #   #  FIND_PACKAGE_ARGS for CUDA was added in https://github.com/microsoft/onnxruntime/commit/87744e5 so it might be possible to delete this patch after upgrading to 1.17.0
  #   ./nvcc-gsl.patch
  # ];

  postPatch =
    ''
      substituteInPlace cmake/libonnxruntime.pc.cmake.in \
        --replace-fail '$'{prefix}/@CMAKE_INSTALL_ @CMAKE_INSTALL_
    ''
    # Don't require the static libraries
    + ''
      substituteInPlace cmake/onnxruntime_providers_tensorrt.cmake \
        --replace-fail \
          'set(onnxparser_link_libs nvonnxparser_static)' \
          'set(onnxparser_link_libs nvonnxparser)'
    ''
    # https://github.com/NixOS/nixpkgs/pull/226734#issuecomment-1663028691
    + optionalString isAarch64Linux ''
      rm -v onnxruntime/test/optimizer/nhwc_transformer_test.cc
    '';

  buildInputs =
    [
      cuda_cccl # cub/cub.cuh
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
      pytorch_clog
      tensorrt
      zlib
    ]
    ++ optionals nccl.meta.available [
      nccl
    ]
    ++ optionals pythonSupport (
      with python3Packages;
      [
        numpy
        pybind11
        packaging
      ]
    );

  enableParallelBuilding = true;

  cmakeDir = "../cmake";

  cmakeFlags =
    [
      (cmakeBool "ABSL_ENABLE_INSTALL" true)
      (cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
      (cmakeBool "FETCHCONTENT_QUIET" false)
      (cmakeBool "onnxruntime_BUILD_SHARED_LIB" true)
      (cmakeBool "onnxruntime_BUILD_UNIT_TESTS" finalAttrs.doCheck)
      (cmakeBool "onnxruntime_ENABLE_LTO" true)
      (cmakeBool "onnxruntime_ENABLE_PYTHON" pythonSupport)
      (cmakeBool "onnxruntime_USE_CUDA" true)
      (cmakeBool "onnxruntime_USE_FULL_PROTOBUF" true) # NOTE: Using protobuf-lite causes linking errors
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
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_DATE" howard-hinnant-date.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_FLATBUFFERS" flatbuffers.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_GOOGLE_NSYNC" nsync.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_GOOGLETEST" gtest.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_MP11" mp11.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_ONNX" onnx.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_PYTORCH_CPUINFO" cpuinfo.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_RE2" re2.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_SAFEINT" safeint.outPath)
    ]
    # Onnx flags
    ++ [
      (cmakeBool "BUILD_ONNX_PYTHON" pythonSupport)
      (cmakeBool "BUILD_SHARED_LIBS" true)
      (cmakeBool "ONNX_BUILD_BENCHMARKS" false)
      (cmakeBool "ONNX_BUILD_TESTS" finalAttrs.doCheck)
      (cmakeBool "ONNX_USE_PROTOBUF_SHARED_LIBS" true)
      (cmakeBool "ONNX_VERIFY_PROTO3" true)
      (cmakeFeature "ONNX_NAMESPACE" "onnx")
    ]
    ++ optionals (majorMinor onnx.version == "1.16") [
      (cmakeBool "ONNX_BUILD_SHARED_LIBS" true)
      (cmakeBool "ONNX_GEN_PB_TYPE_STUBS" false)
    ];

  nativeCheckInputs =
    [
      gtest
    ]
    ++ optionals pythonSupport (
      with python3Packages;
      [
        pytest
        sympy
        onnx
      ]
    );

  # aarch64-linux fails cpuinfo test, because /sys/devices/system/cpu/ does not exist in the sandbox
  # as does testing on the GPU
  doCheck = false;

  postBuild = optionalString pythonSupport ''
    ${python3Packages.python.interpreter} ../setup.py bdist_wheel
  '';

  postInstall = ''
    # perform parts of `tools/ci_build/github/linux/copy_strip_binary.sh`
    install -m644 -Dt $out/include \
      ../include/onnxruntime/core/framework/provider_options.h \
      ../include/onnxruntime/core/providers/cpu/cpu_provider_factory.h \
      ../include/onnxruntime/core/session/onnxruntime_*.h
  '';

  passthru = {
    inherit protobuf;
    tests = optionalAttrs pythonSupport {
      python = python3Packages.onnxruntime;
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
    changelog = "https://github.com/microsoft/onnxruntime/releases/tag/v${finalAttrs.version}";
    # https://github.com/microsoft/onnxruntime/blob/master/BUILD.md#architectures
    platforms = platforms.linux;
    license = licenses.mit;
    maintainers = with maintainers; [
      puffnfresh
      ck3d
      cbourjau
    ];
  };
})
