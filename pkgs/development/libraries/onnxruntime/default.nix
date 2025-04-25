{
  abseil-cpp,
  addDriverRunpath,
  clog,
  cmake,
  config,
  cpuinfo,
  cudaPackages ? { },
  cudaSupport ? config.cudaSupport,
  doCheck ? false,
  eigen,
  fetchFromGitHub,
  fetchpatch,
  flatbuffers_23,
  Foundation,
  glibcLocales,
  gtest,
  howard-hinnant-date,
  lib,
  libiconv,
  libpng,
  microsoft-gsl,
  # TODO(@connorbaker): available is not a reliable indicator of whether NCCL is available (no recursive meta checking)
  ncclSupport ? (cudaSupport && cudaPackages.nccl.meta.available),
  nlohmann_json,
  onnx-tensorrt,
  patchelf,
  pkg-config,
  python3Packages,
  pythonSupport ? true,
  re2,
  stdenv,
  zlib,
}:
let
  inherit (cudaPackages)
    cuda_cccl # cub/cub.cuh -- Only available from CUDA 12.0.
    cuda_compat
    cuda_cudart
    cuda_nvcc
    cudaStdenv
    cudnn
    cudnn-frontend
    flags
    libcublas # cublas_v2.h
    libcufft # cufft.h
    libcurand # curand.h
    libcusparse # cusparse.h
    nccl
    tensorrt
    ;
  inherit (lib) licenses maintainers platforms;
  inherit (lib.attrsets)
    getBin
    getLib
    optionalAttrs
    ;
  inherit (lib.lists) optionals;
  inherit (lib.strings)
    cmakeBool
    cmakeFeature
    cmakeOptionType
    optionalString
    ;
  inherit (stdenv.cc) isClang;
  inherit (python3Packages.onnx.passthru) cppProtobuf;

  isAarch64Linux = stdenv.hostPlatform.system == "aarch64-linux";

  mp11 = fetchFromGitHub {
    owner = "boostorg";
    repo = "mp11";
    tag = "boost-1.82.0";
    hash = "sha256-cLPvjkf2Au+B19PJNrUkTW/VPxybi1MpPxnIl4oo4/o=";
  };

  safeint = fetchFromGitHub {
    owner = "dcleblanc";
    repo = "safeint";
    tag = "3.0.28";
    hash = "sha256-pjwjrqq6dfiVsXIhbBtbolhiysiFlFTnx5XcX77f+C0=";
  };

  onnx = fetchFromGitHub {
    owner = "onnx";
    repo = "onnx";
    tag = "v1.17.0";
    hash = "sha256-9oORW0YlQ6SphqfbjcYb0dTlHc+1gzy9quH/Lj6By8Q=";
  };

  cutlass = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cutlass";
    tag = "v3.5.1";
    hash = "sha256-sTGYN+bjtEqQ7Ootr/wvx3P9f8MCDSSj3qyCWjfdLEA=";
  };

  dlpack = fetchFromGitHub {
    owner = "dmlc";
    repo = "dlpack";
    tag = "v0.6";
    hash = "sha256-YJdZ0cMtUncH5Z6TtAWBH0xtAIu2UcbjnVcCM4tfg20=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;

  pname = "onnxruntime";

  version = "1.21.0";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "onnxruntime";
    tag = "v${finalAttrs.version}";
    hash = "sha256-BaHXpK6Ek+gsld7v+OBM+C3FjrPiyMQYP1liv7mEjho=";
    fetchSubmodules = true;
  };

  # TODO: build server, and move .so's to lib output
  # Python's wheel is stored in a separate dist output
  outputs = [
    "out"
    "dev"
  ] ++ optionals pythonSupport [ "dist" ];

  # No one has time for your games, onnxruntime.
  env.NIX_CFLAGS_COMPILE = builtins.toString [ "-Wno-error" ];

  patches = [
    (fetchpatch {
      url = "https://github.com/microsoft/onnxruntime/commit/55553703eaa8cd01d2b01cc21171a0ea515c888a.patch";
      hash = "sha256-gL1rMNUcteKcjLmdJ+0r67rvNrC31bAyKYx4aeseWkM=";
    })
  ];

  # NOTE: Blocked moving to newer protobuf:
  # https://github.com/microsoft/onnxruntime/issues/21308

  nativeBuildInputs =
    [
      abseil-cpp
      cmake
      patchelf
      pkg-config
      python3Packages.python
      cppProtobuf
      flatbuffers_23
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
    ++ optionals cudaSupport [
      cuda_nvcc
    ];

  buildInputs =
    [
      clog
      cpuinfo
      eigen
      glibcLocales
      howard-hinnant-date
      libpng
      microsoft-gsl
      mp11
      nlohmann_json
      re2
      zlib
    ]
    ++ optionals pythonSupport (
      with python3Packages;
      [
        numpy
        pybind11
        packaging
      ]
    )
    ++ optionals stdenv.hostPlatform.isDarwin [
      Foundation
      libiconv
    ]
    ++ optionals cudaSupport [
      cuda_cccl # CUDA 11.x <cub/cub.cuh>, CUDA 12.x <nv/target>
      cuda_cudart
      cudnn # cudnn.h
      cudnn-frontend # cudnn_frontend.h
      libcublas # cublas_v2.h
      libcufft # cufft.h
      libcurand # curand.h
      libcusparse # cusparse.h
      onnx-tensorrt
      tensorrt
    ]
    ++ optionals ncclSupport [ nccl ];

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
    # Update cudnn_frontend to use our Nixpkgs-provided copy
    + ''
      echo "find_package(cudnn_frontend REQUIRED)" > cmake/external/cudnn_frontend.cmake
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

  # TODO(@connorbaker): This probably won't work for Darwin.
  # Use the same build dir the bash script wrapping the python script wrapping CMake expects us to use.
  cmakeBuildDir = "build/Linux/Release";

  # The CMakeLists.txt file is in the root of the source directory, three levels up from the build directory.
  cmakeDir = "../../../cmake";

  # Silence NVCC warnings from the frontend like:
  # onnxruntime> /nix/store/nrb1wyq26xxghhfky7sr22x27fip35vs-source/absl/types/span.h(154): error #2803-D: attribute namespace "gsl" is unrecognized
  # onnxruntime>   class [[gsl::Pointer]] Span {
  preConfigure = optionalString isClang ''
    appendToVar NVCC_PREPEND_FLAGS "-Xcudafe=--diag_suppress=2803"
  '';

  cmakeFlags =
    [
      # Must set to true to avoid CMake trying to download dependencies.
      (cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
      (cmakeBool "FETCHCONTENT_QUIET" false)
      (cmakeFeature "FETCHCONTENT_TRY_FIND_PACKAGE_MODE" "ALWAYS")
      # Configure build
      (cmakeBool "onnxruntime_BUILD_SHARED_LIB" true)
      (cmakeBool "onnxruntime_BUILD_UNIT_TESTS" finalAttrs.doCheck) # TODO: Build unit tests so long as they don't require GPU access.
      (cmakeBool "onnxruntime_ENABLE_LTO" (!cudaSupport)) # NOTE: Cannot enable LTO when building objects with different compiler versions, like the compiler used by NVCC.
      (cmakeBool "onnxruntime_USE_CUDA" cudaSupport)
      (cmakeBool "onnxruntime_USE_NCCL" ncclSupport)
      (cmakeBool "onnxruntime_ENABLE_PYTHON" true)
      (cmakeBool "onnxruntime_USE_FULL_PROTOBUF" true) # NOTE: Using protobuf_21-lite causes linking errors
    ]
    # Our vendored libraries
    ++ [
      (cmakeFeature "FETCHCONTENT_SOURCE_DIR_DLPACK" dlpack.outPath)
      (cmakeFeature "FETCHCONTENT_SOURCE_DIR_MP11" mp11.outPath)
      (cmakeFeature "FETCHCONTENT_SOURCE_DIR_ONNX" onnx.outPath)
      (cmakeFeature "FETCHCONTENT_SOURCE_DIR_SAFEINT" safeint.outPath)
    ]
    # CUDA
    ++ optionals cudaSupport [
      # TODO(@connorbaker): Unclear if this actually causes onnxruntime to use onnx-tensorrt;
      # the CMake code indicates it merely searches for the library for the parser wherever tensorrt was discovered.
      (cmakeBool "onnxruntime_USE_TENSORRT_BUILTIN_PARSER" false) # Use onnx-tensorrt
      (cmakeBool "onnxruntime_USE_TENSORRT" true)
      (cmakeFeature "onnxruntime_NVCC_THREADS" "1")
      (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" flags.cmakeCudaArchitecturesString)
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_CUTLASS" cutlass.outPath)
    ];

  # TODO: Removed Ninja since it gets added to cmakeFlags and we'd need to filter it out prior to passing it to the Python script.
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
  # NOTE: Removed `--test`.
  # TODO: --use_tensorrt_oss_parser doesn't seem to work; just uses the parsers found in tensorrt_home?
  # NOTE: The build_dir will have the config (Release) automatically added to it, so we use dirname to prevent nesting.
  postConfigure = ''
    pushd "$NIX_BUILD_TOP/$sourceRoot" >/dev/null

    nixLog "building ONNXRuntime"
    python3 "$NIX_BUILD_TOP/$sourceRoot/tools/ci_build/build.py" \
        --build_dir "$(dirname "$NIX_BUILD_TOP/$sourceRoot/''${cmakeBuildDir:?}")" \
        --build \
        --build_shared_lib \
        --skip_tests \
        --update \
        --skip_submodule_sync \
        --config "Release" \
        --parallel ''${NIX_BUILD_CORES:?} \
        --enable_pybind \
        --build_wheel \
        ${optionalString nccl.meta.available ''--enable_nccl --nccl_home "${getLib nccl}"''} \
        --use_cuda \
        --cuda_home "${getLib cuda_cudart}" \
        --cudnn_home "${getLib cudnn}" \
        --use_tensorrt \
        --tensorrt_home "${getLib tensorrt}" \
        --use_full_protobuf \
        --cmake_extra_defines \
          ''${cmakeFlags[@]//-D/} \
          CMAKE_CUDA_COMPILER="${getBin cuda_nvcc}/bin/nvcc" \
          Protobuf_LIBRARIES="${getLib cppProtobuf}/lib/libprotobuf.so"

    popd >/dev/null
  '';

  enableParallelBuilding = true;

  # aarch64-linux fails cpuinfo test, because /sys/devices/system/cpu/ does not exist in the sandbox
  # as does testing on the GPU
  inherit doCheck;

  checkInputs = [ gtest ];

  # NOTE: Because the test cases immediately create and try to run the binaries, we don't have an opportunity
  # to patch them with autoAddDriverRunpath. To get around this, we add the driver runpath to the environment.
  preCheck = optionalString finalAttrs.doCheck (
    ''
      export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH:-}"
    ''
    # NOTE: Ensure cuda_compat has a higher priority than the driver lib when it is in use.
    + optionalString (cudaStdenv.hasJetsonCudaCapability && cuda_compat != null) ''
      addToSearchPath LD_LIBRARY_PATH "${cuda_compat}/compat"
    ''
    + ''
      addToSearchPath LD_LIBRARY_PATH "$(readlink -mnv "${addDriverRunpath.driverLink}/lib")"
    ''
  );

  # Failed tests:
  # ActivationOpTest.ONNX_Gelu
  # CApiTest.custom_op_set_input_memory_type

  requiredSystemFeatures = [ "big-parallel" ] ++ optionals finalAttrs.doCheck [ "cuda" ];

  # perform parts of `tools/ci_build/github/linux/copy_strip_binary.sh`
  postInstall = ''
    install -m644 -Dt "''${!outputInclude:?}/include" \
      "$NIX_BUILD_TOP/$sourceRoot/include/onnxruntime/core/framework/provider_options.h" \
      "$NIX_BUILD_TOP/$sourceRoot/include/onnxruntime/core/providers/cpu/cpu_provider_factory.h" \
      "$NIX_BUILD_TOP/$sourceRoot/include/onnxruntime/core/session/onnxruntime_"*.h
  '';

  # /build/source/onnxruntime/core/session/provider_bridge_ort.cc:1586 void onnxruntime::ProviderSharedLibrary::Ensure() [ONNXRuntimeError] : 1 : FAIL : Failed to load library libonnxruntime_providers_shared.so with error: libonnxruntime_providers_shared.so: cannot open shared object file: No such file or directory
  postFixup = optionalString finalAttrs.doCheck ''
    patchelf --add-rpath "''${!outputLib:?}/lib" "''${!outputBin:?}/bin/onnx_test_runner"
  '';

  passthru = {
    tests = optionalAttrs pythonSupport {
      python = python3Packages.onnxruntime;
    };
  };

  # TODO(@connorbaker): This derivation should contain CPP tests for onnxruntime.

  meta = {
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
    platforms = platforms.unix;
    license = licenses.mit;
    maintainers = with maintainers; [
      puffnfresh
      ck3d
      cbourjau
    ];
  };
})
