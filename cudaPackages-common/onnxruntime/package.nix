{
  abseil-cpp,
  backendStdenv,
  cmake,
  cuda_cccl ? null, # cub/cub.cuh -- Only available from CUDA 12.0.
  cuda_cudart,
  cuda_nvcc,
  cudaAtLeast,
  cudaMajorMinorVersion,
  cudnn,
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
  nlohmann_json,
  nsync,
  onnx-tensorrt,
  onnx,
  onnxruntime, # For passthru.tests
  pkg-config,
  protobuf,
  python3,
  re2,
  srcOnly,
  tensorrt,
  zlib,
}:

let
  inherit (lib.attrsets) getLib optionalAttrs;
  inherit (lib.lists) optionals;
  inherit (lib.strings)
    cmakeBool
    cmakeFeature
    cmakeOptionType
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

  flatbuffers = fetchFromGitHub {
    owner = "google";
    repo = "flatbuffers";
    rev = "refs/tags/v23.5.26";
    hash = "sha256-e+dNPNbCHYDXUS/W+hMqf/37fhVgEGzId6rhP3cToTE=";
  };

  cpuinfoRev = "ca678952a9a8eaa6de112d154e8e104b22f9ab3f";

  cpuinfo = srcOnly {
    __structuredAttrs = true;
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
    __structuredAttrs = true;
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
backendStdenv.mkDerivation {
  __structuredAttrs = true;
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

  build-system = [
    setuptools
    # protobuf4
  ];

  nativeBuildInputs = [
    cmake
    cuda_nvcc
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
      substituteInPlace "cmake/onnxruntime_providers_tensorrt.cmake" \
        --replace-fail \
          'set(onnxparser_link_libs nvonnxparser_static)' \
          'set(onnxparser_link_libs nvonnxparser)'
    ''
    # Use our own externel deps CMake file
    + ''
      rm -f cmake/external/onnxruntime_external_deps.cmake
      install -Dm644 ${./onnxruntime_external_deps.cmake} cmake/external/onnxruntime_external_deps.cmake
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

  preConfigure =
    # Silence NVCC warnings from the frontend like:
    # onnxruntime> /nix/store/nrb1wyq26xxghhfky7sr22x27fip35vs-source/absl/types/span.h(154): error #2803-D: attribute namespace "gsl" is unrecognized
    # onnxruntime>   class [[gsl::Pointer]] Span {
    optionalString isClang ''
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

  # TODO:
  # python3.12-cuda12.6-onnxruntime> In file included from /nix/store/b98gmgf0hv1fmwk6sff5q316mpd8h169-source/googletest/include/gtest/gtest-assertion-result.h:46,
  # python3.12-cuda12.6-onnxruntime>                  from /nix/store/b98gmgf0hv1fmwk6sff5q316mpd8h169-source/googletest/include/gtest/gtest.h:64,
  # python3.12-cuda12.6-onnxruntime>                  from /build/source/onnxruntime/test/util/file_util.cc:3:
  # python3.12-cuda12.6-onnxruntime> /nix/store/b98gmgf0hv1fmwk6sff5q316mpd8h169-source/googletest/include/gtest/gtest-message.h:62:10: fatal error: absl/strings/internal/has_absl_stringify.h: No such file or directory
  # python3.12-cuda12.6-onnxruntime>    62 | #include "absl/strings/internal/has_absl_stringify.h"
  # python3.12-cuda12.6-onnxruntime>       |          ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # python3.12-cuda12.6-onnxruntime> compilation terminated.
  # python3.12-cuda12.6-onnxruntime> make[2]: *** [CMakeFiles/onnxruntime_test_utils.dir/build.make:104: CMakeFiles/onnxruntime_test_utils.dir/build/source/onnxruntime/test/util/file_util.cc.o] Error 1

  buildInputs =
    [
      abseil-cpp
      clog
      cuda_cudart
      cudnn # cudnn.h
      glibcLocales
      libcublas # cublas_v2.h
      libcufft # cufft.h
      libcurand # curand.h
      libcusparse # cusparse.h
      libpng
      # eigen
      microsoft-gsl
      nlohmann_json
      onnx-tensorrt
      onnx
      flatbuffers
      protobuf
      re2
      nsync
      tensorrt
      zlib
    ]
    ++ optionals (cudaAtLeast "12.0") [
      cuda_cccl # <nv/target>
    ]
    ++ optionals nccl.meta.available [ nccl ]

    # TODO: This should depend on doCheck.
    # TODO: Why can't CMake find gtest in checkInputs?
    ++ optionals true [ gtest ];
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
    (cmakeBool "onnxruntime_BUILD_UNIT_TESTS" true)
    (cmakeBool "onnxruntime_ENABLE_LTO" true)
    (cmakeBool "onnxruntime_ENABLE_PYTHON" true)
    (cmakeBool "onnxruntime_USE_CUDA" true)
    (cmakeBool "onnxruntime_USE_FULL_PROTOBUF" true) # NOTE: Using protobuf_21-lite causes linking errors
    (cmakeBool "onnxruntime_USE_NCCL" nccl.meta.available)
    # TODO(@connorbaker): Unclear if this actually causes onnxruntime to use onnx-tensorrt;
    # the CMake code indicates it merely searches for the library for the parser wherever tensorrt was discovered.
    (cmakeBool "onnxruntime_USE_TENSORRT_BUILTIN_PARSER" false) # Use onnx-tensorrt
    (cmakeBool "onnxruntime_USE_TENSORRT" true)
    (cmakeFeature "FETCHCONTENT_TRY_FIND_PACKAGE_MODE" "ALWAYS")
    (cmakeFeature "onnxruntime_NVCC_THREADS" "1")
    (cmakeBool "onnxruntime_USE_PREINSTALLED_EIGEN" true)
    (cmakeOptionType "PATH" "eigen_SOURCE_PATH" eigen.outPath)
    # (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_ABSEIL_CPP" abseil-cpp.src.outPath)
    (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_CUTLASS" cutlass.outPath)
    (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_DATE" date.outPath)
    (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_FLATBUFFERS" flatbuffers.outPath)
    # (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_GOOGLE_NSYNC" nsync.src.outPath)
    (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_MP11" mp11.outPath)
    # (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_ONNX" onnx.src.outPath)
    # (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_RE2" re2.src.outPath)
    (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_SAFEINT" safeint.outPath)

    # The inclusion of CMake files sets targets that onnxruntime needs defined for CMake configuration to succeed.
    (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_PYTORCH_CPUINFO" cpuinfo.outPath)
    # (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_GOOGLETEST" gtest.src.outPath)
  ];

  # nativeCheckInputs = [ gtest ];
  # checkInputs = [ gtest ];
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
