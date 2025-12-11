# TODO: Produce only the binary samples and use to verify the build.
{
  _cuda,
  cmake,
  cudaPackages,
  fetchFromGitHub,
  fetchzip,
  lib,
  runCommand,
  stdenvNoCC,
  writeShellApplication,
  writableTmpDirAsHomeHook,
}:
let
  inherit (cudaPackages)
    backendStdenv
    cuda_cudart
    cuda_nvcc
    cuda_profiler_api
    cudaNamePrefix
    flags
    tensorrt
    ;
  inherit (_cuda.lib) majorMinorPatch;
  inherit (lib)
    cmakeBool
    cmakeFeature
    getAttr
    getBin
    getInclude
    licenses
    maintainers
    optionalString
    replaceStrings
    teams
    ;
in
backendStdenv.mkDerivation (
  finalAttrs:
  let
    atLeast = lib.strings.versionAtLeast finalAttrs.version;
    older = lib.strings.versionOlder finalAttrs.version;
  in

  {
    __structuredAttrs = true;
    strictDeps = true;

    name = "${cudaNamePrefix}-${finalAttrs.pname}-${finalAttrs.version}";

    pname = "tensorrt-oss";

    version = majorMinorPatch tensorrt.version;

    src = fetchFromGitHub (
      {
        owner = "NVIDIA";
        repo = "TensorRT";
      }
      // getAttr finalAttrs.version {
        "10.7.0" = {
          tag = "v10.7.0";
          hash = "sha256-sbp61GverIWrHKvJV+oO9TctFTO4WUmH0oInZIwqF/s=";
        };
        "10.9.0" = {
          tag = "v10.9.0";
          hash = "sha256-J8K9RjeGIem5ZxXyU+Rne8uBbul54ie6P/Y1In2mQ0g=";
        };
        "10.14.1" = {
          tag = "v10.14";
          hash = "sha256-pWvXpXiUriLDYHqro3HWAmO/9wbGznyUrc9qxq/t0/U=";
        };
      }
    );

    nativeBuildInputs = [
      cmake
      cuda_nvcc
    ];

    postPatch = ''
      nixLog "patching $PWD/CMakeLists.txt to avoid manually setting CMAKE_CXX_COMPILER"
      substituteInPlace "$PWD"/CMakeLists.txt \
        --replace-fail \
          'find_program(CMAKE_CXX_COMPILER NAMES $ENV{CXX} g++)' \
          '# find_program(CMAKE_CXX_COMPILER NAMES $ENV{CXX} g++)'

      nixLog "patching $PWD/CMakeLists.txt to use find_package(CUDAToolkit) instead of find_package(CUDA)"
      substituteInPlace "$PWD"/CMakeLists.txt \
        --replace-fail \
          'find_package(CUDA ''${CUDA_VERSION} REQUIRED)' \
          'find_package(CUDAToolkit REQUIRED)'
    ''
    # Fixed since 10.13.2
    # https://github.com/NVIDIA/TensorRT/blame/a9a797daad75baa4c955d8738544e2e7d30a17aa/CMakeLists.txt#L78
    + optionalString (older "10.13.2") ''
      nixLog "patching $PWD/CMakeLists.txt to fix CMake logic error"
      substituteInPlace "$PWD"/CMakeLists.txt \
        --replace-fail \
          'list(APPEND CMAKE_CUDA_ARCHITECTURES SM)' \
          'list(APPEND CMAKE_CUDA_ARCHITECTURES "''${SM}")'
    '';

    cmakeFlags = [
      # Use tensorrt for these components; we only really want the samples.
      (cmakeBool "BUILD_PARSERS" false)
      (cmakeBool "BUILD_PLUGINS" false)
      (cmakeBool "BUILD_SAMPLES" true)

      # Build configuration
      (cmakeFeature "GPU_ARCHS" (replaceStrings [ ";" ] [ " " ] flags.cmakeCudaArchitecturesString))
    ];

    buildInputs = [
      (getInclude cuda_nvcc)
      cuda_cudart
      cuda_profiler_api
      tensorrt
    ];

    passthru = {
      known-samples = [
        "sample_char_rnn"
        "sample_dynamic_reshape"
        "sample_editable_timing_cache"
        "sample_int8_api"
        "sample_io_formats"
        "sample_named_dimensions"
        "sample_non_zero_plugin"
        "sample_onnx_mnist"
        "sample_onnx_mnist_coord_conv_ac"
        "sample_progress_monitor"
        "trtexec"
      ];

      sample-data =
        let
          # Releases prior to 10.14.1 don't have any sample data available to them, so just use the 10.14.1 release's
          # sample data.
          sample-data_10_14_1 = {
            url = "https://github.com/NVIDIA/TensorRT/releases/download/v10.14/tensorrt_sample_data_20251106.zip";
            hash = "sha256-IA1pH8idtk/7FD1Tf0hKtyP7A5SW/2ugezyBRluG8yk=";
          };
        in
        fetchzip (
          if older "10.14.1" then
            sample-data_10_14_1
          else
            getAttr finalAttrs.version {
              "10.14.1" = sample-data_10_14_1;
            }
        );

      testers = {
        run-sample = writeShellApplication {
          name = "run-sample";

          derivationArgs = {
            __structuredAttrs = true;
            strictDeps = true;

          };

          runtimeInputs = [ finalAttrs.finalPackage ];

          text = ''
            if (($# == 0)); then
              echo "Expected at least one argument!"
              echo "Available samples:"
              ls -1 "${getBin finalAttrs.finalPackage}/bin"
              exit 1
            fi

            # Just get the help message directly
            if [[ "''${2:-}" == "--help" ]]; then
              "$1" "$2"
              exit 0
            fi

            if [[ -L data ]]; then
              echo "Cleaning up data symlink"
              rm data
            fi

            echo "Symlinking data to ${finalAttrs.passthru.sample-data.outPath}"
            ln -sv "${finalAttrs.passthru.sample-data.outPath}" data

            echo "Running $*"
            "$@"

            if [[ -L data ]]; then
              echo "Cleaning up data symlink"
              rm data
            fi
          '';
        };
      };

      tests =
        let
          mkTest =
            cmdArgs:
            stdenvNoCC.mkDerivation {
              __structuredAttrs = true;
              strictDeps = true;
              name = "test-tensorrt-${lib.head cmdArgs}";
              inherit cmdArgs;
              nativeBuildInputs = [
                finalAttrs.finalPackage
                writableTmpDirAsHomeHook
              ];
              dontUnpack = true;
              dontConfigure = true;
              buildPhase = ''
                runHook preBuild

                nixLog "symlinking data to ${finalAttrs.passthru.sample-data.outPath}"
                ln -sv "${finalAttrs.passthru.sample-data.outPath}" data
                nixLog "running ''${cmdArgs[*]@Q}"
                "''${cmdArgs[@]}" || {
                  nixErrorLog "command failed with exit code $?"
                  exit 1
                }

                runHook postBuild
              '';
              installPhase = ''
                touch "$out"
              '';
            };
        in
        {
          sample_onnx_mnist = mkTest [ "sample_onnx_mnist" ];
          # sample_onnx_mnist = finalAttrs.testers.run-sample
          # ${libnvinfer-samples}/bin/sample_onnx_mnist --datadir ${libnvinfer-samples}/data/mnist
        };
    };

    meta = {
      description = "Open Source Software (OSS) components of NVIDIA TensorRT";
      homepage = "https://github.com/NVIDIA/TensorRT";
      license = licenses.asl20;
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      teams = [ teams.cuda ];
      maintainers = with maintainers; [ connorbaker ];
    };
  }
)
