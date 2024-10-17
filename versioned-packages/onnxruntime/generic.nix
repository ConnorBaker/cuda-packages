{
  backendStdenv,
  cmake,
  cuda_cccl, # cub/cub.cuh
  cuda_cudart,
  cuda_nvcc,
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
  fetchpatch2,
  srcOnly,
  nsync,
  onnx_1_14,
  onnx_1_16,
  onnx-tensorrt_8_5,
  onnx-tensorrt_10_4,
  pkg-config,
  python3Packages,
  pythonSupport ? false,
  re2,
  tensorrt_8_5,
  tensorrt_10_4,
  zlib,
  # Package overrides
  version,
  # Packages
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
  isAarch64Linux = backendStdenv.hostPlatform.system == "aarch64-linux";

  hash =
    {
      "1.16.3" = "sha256-bTW9Pc3rvH+c8VIlDDEtAXyA3sajVyY5Aqr6+SxaMF4=";
      "1.18.2" = "sha256-Z9EezJ1WGd2g9XwXIjp1h/rn/a0JCahvOUUkZc+wKtQ=";
      "1.19.2" = "sha256-LLTPDvdWdK+2yo7uRVzjEQOEmc2ISEQ1Hp2SZSYSpSU=";
    }
    .${version};

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "onnxruntime";
    rev = "refs/tags/v${version}";
    inherit hash;
    fetchSubmodules = true;
  };

  # Eigen is the same for each release so far.
  # NOTE: Though 1.16.3 has a patch in tree for Eigen, it does not apply cleanly so we ignore it.
  eigen =
    assert (
      builtins.elem version [
        "1.16.3"
        "1.18.2"
        "1.19.2"
      ]
    );
    fetchFromGitLab {
      owner = "libeigen";
      repo = "eigen";
      rev = "e7248b26a1ed53fa030c5c459f7ea095dfd276ac";
      hash = "sha256-uQ1YYV3ojbMVfHdqjXRyUymRPjJZV3WHT36PTxPRius=";
    };

  # Onnx has the patches from the onnxruntime's tree applied already
  onnx =
    {
      "1.16.3" = onnx_1_14;
      "1.18.2" = onnx_1_16;
      "1.19.2" = onnx_1_16;
    }
    .${version};

  cutlass =
    let
      cutlassVersion =
        {
          "1.16.3" = "3.0.0";
          "1.18.2" = "3.1.0";
          "1.19.2" = "3.5.0";
        }
        .${version};
      cutlassHash =
        {
          "3.0.0" = "sha256-YPD5Sy6SvByjIcGtgeGH80TEKg2BtqJWSg46RvnJChY=";
          "3.1.0" = "sha256-mpaiCxiYR1WaSSkcEPTzvcREenJWklD+HRdTT5/pD54=";
          "3.5.0" = "sha256-D/s7eYsa5l/mfx73tE4mnFcTQdYqGmXa9d9TCryw4e4=";
        }
        .${cutlassVersion};
      cutlassSource = fetchFromGitHub {
        owner = "NVIDIA";
        repo = "cutlass";
        rev = "refs/tags/v${cutlassVersion}";
        hash = cutlassHash;
      };
      patchedCutlassSource = srcOnly {
        strictDeps = true;
        name = "cutlass-source-${cutlassVersion}-patched";
        src = cutlassSource;
        patches =
          optionals (version == "1.16.3") [
            "${src}/cmake/patches/cutlass/cutlass.patch"
          ]
          ++ optionals (version == "1.19.2") [
            "${src}/cmake/patches/cutlass/cutlass_3.5.0.patch"
          ];
      };
      usePatchedCutlassSource = builtins.elem version [
        "1.16.3"
        "1.19.2"
      ];
    in
    if usePatchedCutlassSource then patchedCutlassSource else cutlassSource;

  date =
    let
      dateVersion =
        {
          "1.16.3" = "2.4.1";
          "1.18.2" = "3.0.1";
          "1.19.2" = "3.0.1";
        }
        .${version};
      dateHash =
        {
          "2.4.1" = "sha256-BYL7wxsYRI45l8C3VwxYIIocn5TzJnBtU0UZ9pHwwZw=";
          "3.0.1" = "sha256-ZSjeJKAcT7mPym/4ViDvIR9nFMQEBCSUtPEuMO27Z+I=";
        }
        .${dateVersion};
    in
    fetchFromGitHub {
      owner = "HowardHinnant";
      repo = "date";
      rev = "refs/tags/v${dateVersion}";
      hash = dateHash;
    };

  mp11 =
    let
      mp11Version =
        {
          "1.16.3" = "1.79.0";
          "1.18.2" = "1.82.0";
          "1.19.2" = "1.82.0";
        }
        .${version};
      mp11Hash =
        {
          "1.79.0" = "sha256-ZxgPDLvpISrjpEHKpLGBowRKGfSwTf6TBfJD18yw+LM=";
          "1.82.0" = "sha256-cLPvjkf2Au+B19PJNrUkTW/VPxybi1MpPxnIl4oo4/o=";
        }
        .${mp11Version};
    in
    fetchFromGitHub {
      owner = "boostorg";
      repo = "mp11";
      rev = "refs/tags/boost-${mp11Version}";
      hash = mp11Hash;
    };

  # Same for all versions so far.
  safeint =
    assert (
      builtins.elem version [
        "1.16.3"
        "1.18.2"
        "1.19.2"
      ]
    );
    fetchFromGitHub {
      owner = "dcleblanc";
      repo = "safeint";
      rev = "refs/tags/3.0.28";
      hash = "sha256-PK1ce4C0uCR4TzLFg+elZdSk5DdPCRhhwT3LvEwWnPU=";
    };

  flatbuffers =
    let
      flatbuffersVersion =
        {
          "1.16.3" = "1.12.0";
          "1.18.2" = "23.5.26";
          "1.19.2" = "23.5.26";
        }
        .${version};
      flatbuffersHash =
        {
          "1.12.0" = "sha256-L1B5Y/c897Jg9fGwT2J3+vaXsZ+lfXnskp8Gto1p/Tg=";
          "23.5.26" = "sha256-e+dNPNbCHYDXUS/W+hMqf/37fhVgEGzId6rhP3cToTE=";
        }
        .${flatbuffersVersion};
    in
    fetchFromGitHub {
      owner = "google";
      repo = "flatbuffers";
      rev = "v${flatbuffersVersion}";
      hash = flatbuffersHash;
    };

  cpuinfoRev =
    {
      # Use a different version of cpuinfo that what is pinned in onnxruntime so we can benefit from patches which expose
      # aliases in CMake.
      "1.16.3" = "29ad0cbb360653c59204bba8ef658ffcba264a67";
      "1.18.2" = "959002f82d7962a473d8bf301845f2af720e0aa4";
      "1.19.2" = "ca678952a9a8eaa6de112d154e8e104b22f9ab3f";
    }
    .${version};

  cpuinfo =
    let
      cpuinfoHash =
        {
          "1.16.3" = "sha256-lI6uKh2j4GfsKiR1om5c0Es6r6gbYFYv7BVAQV/TiN8=";
          "1.18.2" = "sha256-nOSaLZGqmt+8W5Ut9QHDKznh1cekl1jL2ghCM4mgbgc=";
          "1.19.2" = "sha256-UKy9TIiO/UJ5w+qLRlMd085CX2qtdVH2W3rtxB5r6MY=";
        }
        .${version};
      cpuinfoSource = fetchFromGitHub {
        owner = "pytorch";
        repo = "cpuinfo";
        rev = cpuinfoRev;
        hash = cpuinfoHash;
      };
      patchedCpuinfoSource = srcOnly {
        strictDeps = true;
        name = "cpuinfo-source-${builtins.substring 0 8 cpuinfoRev}-patched";
        src = cpuinfoSource;
        patches =
          optionals
            (builtins.elem version [
              "1.18.2"
              "1.19.2"
            ])
            [
              "${src}/cmake/patches/cpuinfo/9bb12d342fd9479679d505d93a478a6f9cd50a47.patch"
            ];
      };
      usePatchedCpuinfoSource = builtins.elem version [
        "1.18.2"
        "1.19.2"
      ];
    in
    if usePatchedCpuinfoSource then patchedCpuinfoSource else cpuinfoSource;

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

  effectiveTensorRT =
    {
      "1.16.3" = tensorrt_8_5;
      "1.18.2" = if tensorrt_10_4.meta.available then tensorrt_10_4 else tensorrt_8_5;
      "1.19.2" = tensorrt_10_4;
    }
    .${version};
  effectiveCudnn = effectiveTensorRT.passthru.cudnn;
  effectiveOnnxTensorRT =
    {
      "1.16.3" = onnx-tensorrt_8_5;
      "1.18.2" = if tensorrt_10_4.meta.available then onnx-tensorrt_10_4 else onnx-tensorrt_8_5;
      "1.19.2" = onnx-tensorrt_10_4;
    }
    .${version};
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

  inherit src;

  # Clang generates many more warnings than GCC does, so we just disable erroring on warnings entirely.
  env = optionalAttrs isClang {
    NIX_CFLAGS_COMPILE = "-Wno-error";
  };

  nativeBuildInputs =
    [
      cmake
      cuda_nvcc
      pkg-config
      protobuf_21
      python3Packages.python
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
    );

  patches =
    optionals (version == "1.16.3") [
      (fetchpatch2 {
        name = "cuda-fix-microsoft-gsl.patch";
        url = "https://github.com/microsoft/onnxruntime/pull/17843/commits/46e25263ee6e76b105729a3c9b28f0bdbcbb793f.patch";
        hash = "sha256-pOpHTFA8f5To4V7iKQ67dmrhuAvSNcYzgAvtEM12K6w=";
      })
    ]
    ++ optionals (version == "1.18.2") [
      # Incorporate a patch that has landed upstream which exposes new
      # 'abseil-cpp' libraries & modifies the 're2' CMakeLists to fix a
      # configuration error that around missing 'gmock' exports.
      ./update-re2.patch
    ];

  postPatch =
    ''
      substituteInPlace cmake/libonnxruntime.pc.cmake.in \
        --replace-fail '$'{prefix}/@CMAKE_INSTALL_ @CMAKE_INSTALL_
    ''
    # We don't need clog aliases because we use a slightly newer version for 1.16.3 which includes CMake changes to
    # create these aliases for us.
    + optionalString (version == "1.16.3") ''
      substituteInPlace cmake/external/onnxruntime_external_deps.cmake \
        --replace-fail \
          "add_library(cpuinfo::cpuinfo ALIAS cpuinfo)" \
          "" \
        --replace-fail \
          "add_library(cpuinfo::clog ALIAS clog)" \
          ""
    ''
    # Don't require the static libraries
    + ''
      substituteInPlace ${
        if version == "1.16.3" then
          "cmake/onnxruntime_providers.cmake"
        else
          "cmake/onnxruntime_providers_tensorrt.cmake"
      } \
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
  preConfigure = optionalString isClang ''
    export NVCC_PREPEND_FLAGS+=" -Xcudafe=--diag_suppress=2803"
  '';

  buildInputs =
    [
      cuda_cccl # cub/cub.cuh
      cuda_cudart
      effectiveCudnn # cudnn.h
      glibcLocales
      libcublas # cublas_v2.h
      libcufft # cufft.h
      libcurand # curand.h
      libcusparse # cusparse.h
      libpng
      microsoft-gsl
      nlohmann_json
      effectiveOnnxTensorRT
      effectiveTensorRT
      zlib
    ]
    ++ optionals
      (builtins.elem version [
        "1.18.2"
        "1.19.2"
      ])
      [
        clog
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
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_FLATBUFFERS" flatbuffers.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_GOOGLE_NSYNC" nsync.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_MP11" mp11.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_ONNX" onnx.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_RE2" re2.src.outPath)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_SAFEINT" safeint.outPath)

      # The inclusion of CMake files sets targets that onnxruntime needs defined for CMake configuration to succeed.
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_PYTORCH_CPUINFO" cpuinfo.outPath)
    ]
    ++ optionals (version != "1.16.3") [
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_GOOGLETEST" gtest.src.outPath)
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
    # TODO(@connorbaker): Fix this error when building with Clang:
    # cuda11.8-onnxruntime> /nix/store/gvs1z5fzx12xp787ays1ncqlfgv3j1c8-gcc-13.3.0/include/c++/13.3.0/bits/stl_map.h:595:15: error: expression contains unexpanded parameter pack '_Args'
    # cuda11.8-onnxruntime> if constexpr (__usable_key< __decltype(__a), remove_reference_t< _Args> > )
    broken = isClang && version == "1.16.3";
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
