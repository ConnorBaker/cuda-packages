{
  abseil-cpp,
  addDriverRunpath,
  buildPythonPackage,
  config,
  cudaPackages,
  cudaSupport ? config.cudaSupport,
  callPackage,
  clog,
  cmake,
  coloredlogs,
  cpuinfo,
  doCheck ? false,
  fetchFromGitHub,
  flatbuffers,
  glibcLocales,
  gtest,
  lib,
  libpng,
  microsoft-gsl,
  nlohmann_json,
  onnx-tensorrt,
  onnx,
  onnxruntime, # For passthru.tests
  patchelf,
  pkg-config,
  pybind11,
  re2,
  setuptools,
  stdenv,
  sympy,
  zlib,
}:
let
  inherit (cudaPackages)
    cuda_cccl # cub/cub.cuh -- Only available from CUDA 12.0.
    cuda_cudart
    cuda_nvcc
    cudaOlder
    cudnn-frontend
    cudnn
    flags
    libcublas # cublas_v2.h
    libcufft # cufft.h
    libcurand # curand.h
    libcusparse # cusparse.h
    nccl
    tensorrt
    ;
  inherit (lib) licenses maintainers teams;
  inherit (lib.attrsets)
    attrValues
    getBin
    getLib
    mapAttrs
    ;
  inherit (lib.lists) optionals;
  inherit (lib.strings)
    cmakeBool
    cmakeFeature
    cmakeOptionType
    optionalString
    ;
  inherit (lib.trivial) const flip;
  inherit (stdenv.cc) isClang;
  inherit (onnx.passthru) cppProtobuf;

  isAarch64Linux = stdenv.hostPlatform.system == "aarch64-linux";

  vendored = mapAttrs (const (flip callPackage { })) {
    cutlass = ./cutlass.nix;
    date = ./date.nix;
    eigen = ./eigen.nix;
    flatbuffers = ./flatbuffers.nix;
    safeint = ./safeint.nix;
  };

  # TODO: Only building and installing Python package; no installation of the C++ library.

  finalAttrs = {
    # Must opt-out of __structuredAttrs which is set to true by default by cudaPackages.callPackage, but currently
    # incompatible with Python packaging: https://github.com/NixOS/nixpkgs/pull/347194.
    __structuredAttrs = false;

    pname = "onnxruntime";

    # NOTE: Using newer version because nsync has been removed from the build system
    version = "1.20.1-unstable-2024-12-03";

    # TODO: Currently failing with errors like:
    #
    # python3.12-onnxruntime> /build/source/onnxruntime/contrib_ops/cuda/bert/fastertransformer_decoder_attention/decoder_masked_multihead_attention_impl.h(24):
    # error #20281-D: in whole program compilation mode ("-rdc=false"), a __global__ function template instantiation or specialization
    # ("onnxruntime::contrib::cuda::masked_multihead_attention_kernel<float, (int)128, (int)4, (int)32, (int)64> ") will be required to have
    # a definition in the current translation unit, when "-static-global-template-stub" will be set to "true" by default in the future. To
    # resolve this issue, either use "-rdc=true", or explicitly set "-static-global-template-stub=false" (but see nvcc documentation about
    # downsides of turning it off)
    #
    # This was fixed upstream by https://github.com/microsoft/onnxruntime/pull/23562, but uses separable compilation which doesn't work on NixOS for some reason.
    # To fix this, we'll need to fix that.

    src = fetchFromGitHub {
      owner = "microsoft";
      repo = "onnxruntime";
      rev = "9b9f881475a12991d0abba0095c26dad8a4de5e9";
      hash = "sha256-exXR7TmyzlBnM2njwkIvZ7Iko+ZF8vx6qrm8EYJwd+I=";
      fetchSubmodules = true;
    };

    pyproject = true;

    # No one has time for your games, onnxruntime.
    env.NIX_CFLAGS_COMPILE = builtins.toString [ "-Wno-error" ];

    # NOTE: Blocked moving to newer protobuf:
    # https://github.com/microsoft/onnxruntime/issues/21308

    build-system = [
      cmake
      setuptools
      # protobuf4
    ];

    nativeBuildInputs = [
      cppProtobuf
      cuda_nvcc
      patchelf
      pkg-config
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

    buildInputs =
      # Normal build inputs which are taken as-is from Nixpkgs
      [
        abseil-cpp
        clog
        cppProtobuf
        cuda_cccl # CUDA 11.x <cub/cub.cuh>, CUDA 12.x <nv/target>
        cuda_cudart
        cudnn # cudnn.h
        cudnn-frontend # cudnn_frontend.h
        cpuinfo
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
        re2
        tensorrt
        zlib
      ]
      ++ optionals nccl.meta.available [ nccl ]
      # Build inputs used for source.
      # TODO(@connorbaker): Package these and get onnxruntime to use them instead of building them in the derivation.
      ++ attrValues vendored;

    dependencies = [
      coloredlogs
      flatbuffers
      sympy
    ];

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

    # Use the same build dir the bash script wrapping the python script wrapping CMake expects us to use.
    # NOTE: Python script will actually use build/Linux/Release!
    cmakeBuildDir = "build/Linux";

    # The CMakeLists.txt file is in the root of the source directory, two levels up from the build directory.
    cmakeDir = "../../cmake";

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
        (cmakeFeature "FETCHCONTENT_TRY_FIND_PACKAGE_MODE" "ALWAYS")
        # Configure build
        (cmakeBool "onnxruntime_BUILD_SHARED_LIB" true)
        (cmakeBool "onnxruntime_BUILD_UNIT_TESTS" finalAttrs.doCheck) # TODO: Build unit tests so long as they don't require GPU access.
        (cmakeBool "onnxruntime_ENABLE_LTO" false) # NOTE: Cannot enable LTO when building objects with different compiler versions, like the compiler used by NVCC.
        (cmakeBool "onnxruntime_ENABLE_PYTHON" true)
        (cmakeBool "onnxruntime_USE_CUDA" true)
        (cmakeBool "onnxruntime_USE_FULL_PROTOBUF" true) # NOTE: Using protobuf_21-lite causes linking errors
        (cmakeBool "onnxruntime_USE_NCCL" nccl.meta.available) # TODO(@connorbaker): available is not a reliable indicator of whether NCCL is available (no recursive meta checking)
        # TODO(@connorbaker): Unclear if this actually causes onnxruntime to use onnx-tensorrt;
        # the CMake code indicates it merely searches for the library for the parser wherever tensorrt was discovered.
        (cmakeBool "onnxruntime_USE_TENSORRT_BUILTIN_PARSER" false) # Use onnx-tensorrt
        (cmakeBool "onnxruntime_USE_TENSORRT" true)
        (cmakeFeature "onnxruntime_NVCC_THREADS" "1")
        (cmakeFeature "CMAKE_CUDA_ARCHITECTURES" flags.cmakeCudaArchitecturesString)
      ]
      # Our vendored libraries
      ++ [
        (cmakeBool "onnxruntime_USE_PREINSTALLED_EIGEN" true)
        (cmakeOptionType "PATH" "eigen_SOURCE_PATH" vendored.eigen.outPath)
        (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_CUTLASS" vendored.cutlass.outPath)
        (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_DATE" vendored.date.outPath)
        (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_FLATBUFFERS" vendored.flatbuffers.outPath)
        (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_SAFEINT" vendored.safeint.outPath)
      ];

    # TODO: Removed Ninja since it gets added to cmakeFlags and we'd need to filter it out prior to passing it to the Python script.
    postConfigure =
      # Return to the root of the source directory, leaving and deleting CMake's build directory.
      ''
        cd "$NIX_BUILD_TOP/$sourceRoot"
        rm -rf "''${cmakeBuildDir:?}"
      ''
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
      + ''
        python3 "$NIX_BUILD_TOP/$sourceRoot/tools/ci_build/build.py" \
            --build_dir "''${cmakeBuildDir:?}" \
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

        pushd "$NIX_BUILD_TOP/$sourceRoot/$cmakeBuildDir/Release"
      '';

    enableParallelBuilding = true;

    # Let the Python script from onnxruntime handle wheel creation.
    # TODO: Did this break the build, even before configurePhase ran?
    dontUsePypaBuild = true;

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

    # aarch64-linux fails cpuinfo test, because /sys/devices/system/cpu/ does not exist in the sandbox
    # as does testing on the GPU
    inherit doCheck;

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
        "$NIX_BUILD_TOP/$sourceRoot/include/onnxruntime/core/framework/provider_options.h" \
        "$NIX_BUILD_TOP/$sourceRoot/include/onnxruntime/core/providers/cpu/cpu_provider_factory.h" \
        "$NIX_BUILD_TOP/$sourceRoot/include/onnxruntime/core/session/onnxruntime_"*.h
    '';

    # /build/source/onnxruntime/core/session/provider_bridge_ort.cc:1586 void onnxruntime::ProviderSharedLibrary::Ensure() [ONNXRuntimeError] : 1 : FAIL : Failed to load library libonnxruntime_providers_shared.so with error: libonnxruntime_providers_shared.so: cannot open shared object file: No such file or directory
    postFixup = optionalString finalAttrs.doCheck ''
      patchelf --add-rpath "$out/lib" "$out/bin/onnx_test_runner"
    '';

    passthru = {
      tests = {
        gpu = onnxruntime.override { doCheck = true; };
      };
    };

    meta = {
      broken = !cudaSupport || cudaOlder "12";
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
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      license = licenses.mit;
      maintainers =
        (with maintainers; [
          puffnfresh
          ck3d
          cbourjau
        ])
        ++ teams.cuda.members;
    };
  };
in
buildPythonPackage finalAttrs
