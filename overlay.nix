# This is largely a shim for Nixpkgs.
final': prev':
let
  inherit (prev'.lib.attrsets) genAttrs getBin getOutput;
  inherit (prev'.lib.lists)
    concatMap
    filter
    map
    optionals
    ;
  inherit (prev'.lib.fixedPoints) composeManyExtensions;
  inherit (prev'.lib.strings) cmakeOptionType;

  extraAutoCalledPackages =
    final: prev: import (prev.path + "/pkgs/top-level/by-name-overlay.nix") ./pkgs/by-name final prev;

  extraTesterPackages = final: prev: {
    testers = prev.testers // {
      makeMainWithRunpath = final.callPackage ./pkgs/build-support/testers/makeMainWithRunpath { };
    };

    tests = prev.tests // {
      testers = prev.tests.testers // {
        makeMainWithRunpath =
          final.callPackages ./pkgs/build-support/testers/makeMainWithRunpath/tests.nix
            { };
      };
    };
  };

  extraPythonPackages = final: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions or [ ] ++ [
      (
        finalPythonPackages: prevPythonPackages:
        {
          causal-conv1d = prevPythonPackages.causal-conv1d.overrideAttrs (prevAttrs: {
            # Missing cuda_nvcc in nativeBuildInputs
            nativeBuildInputs = prevAttrs.nativeBuildInputs ++ [ final.cudaPackages.cuda_nvcc ];
            # Cannot have cuda_nvcc in both nativeBuildInputs and buildInputs without strictDeps being enabled.
            buildInputs = filter (drv: drv != final.cudaPackages.cuda_nvcc) prevAttrs.buildInputs;
            # TODO: https://github.com/Dao-AILab/causal-conv1d/blob/82867a9d2e6907cc0f637ac6aff318f696838548/setup.py#L40
            # TODO: https://github.com/Dao-AILab/causal-conv1d/blob/82867a9d2e6907cc0f637ac6aff318f696838548/setup.py#L173
            # TODO: https://github.com/Dao-AILab/causal-conv1d/blob/82867a9d2e6907cc0f637ac6aff318f696838548/setup.py#L267
            # NOTE: "No CUDA runtime is found" is an expected message given we don't allow GPU access in the build.
            env = prevAttrs.env // {
              CUDA_HOME = "${getBin final.cudaPackages.cuda_nvcc}";
            };
          });

          mamba-ssm = prevPythonPackages.mamba-ssm.overrideAttrs (prevAttrs: {
            # Missing cuda_nvcc in nativeBuildInputs
            nativeBuildInputs = prevAttrs.nativeBuildInputs ++ [ final.cudaPackages.cuda_nvcc ];
            # Cannot have cuda_nvcc in both nativeBuildInputs and buildInputs without strictDeps being enabled.
            buildInputs = filter (drv: drv != final.cudaPackages.cuda_nvcc) prevAttrs.buildInputs;
            # NOTE: "No CUDA runtime is found" is an expected message given we don't allow GPU access in the build.
            # TODO: https://github.com/state-spaces/mamba/blob/2e16fc3062cdcd4ebef27a9aa4442676e1c7edf4/setup.py#L175
            # TODO: https://github.com/state-spaces/mamba/blob/2e16fc3062cdcd4ebef27a9aa4442676e1c7edf4/setup.py#L44
            # TODO: https://github.com/state-spaces/mamba/blob/2e16fc3062cdcd4ebef27a9aa4442676e1c7edf4/setup.py#L282
            env = prevAttrs.env // {
              CUDA_HOME = "${getBin final.cudaPackages.cuda_nvcc}";
            };
          });

          # Fails due to distutils missing.
          # NOTE: Why does it take overridePythonAttrs to make this work?
          mmengine = prevPythonPackages.mmengine.overridePythonAttrs { doCheck = false; };

          mmcv = prevPythonPackages.mmcv.overridePythonAttrs (prevAttrs: {
            # CUDA_HOME is only expected to contain a working nvcc in /bin.
            env.CUDA_HOME = final.lib.optionalString finalPythonPackages.torch.cudaSupport "${final.lib.getBin final.cudaPackages.cuda_nvcc}";
            # Fails due to distutils missing.
            disabledTests = prevAttrs.disabledTests ++ [ "test_env" ];
          });

          torch =
            # Could not find CUPTI library, using CPU-only Kineto build
            # Could NOT find NCCL (missing: NCCL_INCLUDE_DIR)
            # USE_TENSORRT is unset in the printed config at the end of configurePhase.
            # Not sure if that's used directly or passed through to one of the vendored projects.
            (prevPythonPackages.torch.override {
              # PyTorch doesn't need Triton to build.
              # Just include it in whichever package consumes pytorch.
              tritonSupport = false;
            }).overrideAttrs
              (prevAttrs: {
                buildInputs =
                  prevAttrs.buildInputs or [ ]
                  ++ [
                    final.cudaPackages.libcusparse_lt
                    final.cudaPackages.libcudss
                    final.cudaPackages.libcufile
                  ]
                  ++ optionals final.cudaPackages.nccl.meta.available [ final.cudaPackages.nccl.static ];

                USE_CUFILE = 1;
              });

          triton = prevPythonPackages.triton.overrideAttrs (
            let
              inherit (final.stdenv) cc;
            in
            finalAttrs: prevAttrs: {
              env = prevAttrs.env or { } // {
                CC = "${cc}/bin/${cc.targetPrefix}cc";
                CXX = "${cc}/bin/${cc.targetPrefix}c++";
              };
              preConfigure =
                prevAttrs.preConfigure or ""
                # Patch in our compiler.
                # https://github.com/triton-lang/triton/blob/cf34004b8a67d290a962da166f5aa2fc66751326/python/triton/runtime/build.py#L25
                + ''
                  substituteInPlace "$NIX_BUILD_TOP/$sourceRoot/python/triton/runtime/build.py" \
                    --replace-fail \
                      'cc = os.environ.get("CC")' \
                      'cc = "${finalAttrs.env.CC}"'
                '';
            }
          );

          onnxruntime = finalPythonPackages.callPackage ./pkgs/development/python-modules/onnxruntime {
            onnxruntime = final.onnxruntime.override {
              python3Packages = finalPythonPackages;
              pythonSupport = true;
            };
          };

          onnx-tensorrt = finalPythonPackages.callPackage ./pkgs/development/python-modules/onnx-tensorrt {
            onnx-tensorrt = final.onnx-tensorrt.override {
              python3Packages = finalPythonPackages;
              pythonSupport = true;
            };
          };

          onnx = finalPythonPackages.callPackage ./pkgs/development/python-modules/onnx {
            onnx = final.onnx.override {
              python3Packages = finalPythonPackages;
              pythonSupport = true;
            };
          };
        }
        // genAttrs [
          "bitsandbytes"
          "codetr"
          "cuda-bindings"
          "cuda-python"
          "cupy"
          "cutlass"
          "flash-attn"
          "mmdet"
          "modelopt"
          "modelopt-core"
          "nvcomp"
          "nvdlfw-inspect"
          "pyclibrary"
          "pycuda"
          "pyglove"
          "schedulefree"
          "tensorrt"
          "torch-tensorrt"
          "transformer-engine"
          "warp"
        ] (name: finalPythonPackages.callPackage (./pkgs/development/python-modules + "/${name}") { })
      )
    ];
  };

  extraPackages =
    final: prev:
    let
      cudartJoined = final.symlinkJoin {
        name = "cudart-joined";
        paths = concatMap (
          # Don't include the stubs in the joined package.
          output: optionals (output != "stubs") [ final.cudaPackages.cuda_cudart.${output} ]
        ) final.cudaPackages.cuda_cudart.outputs;
      };
      nvccJoined = final.symlinkJoin {
        name = "nvcc-joined";
        paths = map (output: final.cudaPackages.cuda_nvcc.${output}) final.cudaPackages.cuda_nvcc.outputs;
      };
    in
    {
      # NOTE: opencv is an alias to opencv4; make sure to override the actual derivation and not the alias.
      opencv4 = prev.opencv4.overrideAttrs (
        let
          contribSrc = final.fetchFromGitHub {
            owner = "opencv";
            repo = "opencv_contrib";
            rev = "2a82fa641582f1af9959fd31cef7888ad5a39c14";
            hash = "sha256-cfGBqo/OT93oV09jqhHF4GfWaJGFa0IzZXtoANnQBSI=";
          };
        in
        finalAttrs: prevAttrs: {
          src = final.fetchFromGitHub {
            owner = "opencv";
            repo = "opencv";
            rev = "28d410cecff7a6fbeac3f1aba3ecc78248671829";
            hash = "sha256-CsG54cDkKJmpF04lccycqOF2c61QKNERmN8A0KrrlP4=";
          };

          # NOTE: 4.12 doesn't work with CUDA 13.0.
          # There are a number of upstream PRs required, including at least
          # https://github.com/opencv/opencv/pull/27636.
          version = "4.12.0-unstable-2025-08-20";

          postUnpack = ''
            cp --no-preserve=mode -r "${contribSrc}/modules" "$NIX_BUILD_TOP/source/opencv_contrib"
          '';

          cmakeFlags =
            prevAttrs.cmakeFlags or [ ]
            ++ final.lib.optionals (final.cudaPackages.cudaAtLeast "13.0") [
              # NOTE: -Wno-deprecated-declarations:
              # Huge number of deprecation warnings for CUDA 13.0
              # /build/source/opencv_contrib/cudev/include/opencv2/cudev/util/vec_traits.hpp:138:98: warning: 'double4' is deprecated: use double4_16a or double4_32a [-Wdeprecated-declarations]
              #   138 | CV_CUDEV_VEC_TRAITS_INST(double)
              # NOTE: -DCCCL_IGNORE_DEPRECATED_CPP_DIALECT=1:
              # TODO(@connorbaker): This is an odd error to get given that we *do* change the language standard for OpenCV to C++17:
              # https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/libraries/opencv/4.x.nix#L466
              # In file included from /nix/store/kmmz1q61p1a6mv1c8yw9wihmdakqlc11-cuda13.0-cuda_cccl-13.0.50-include/include/thrust/detail/config/config.h:37,
              #                  from /nix/store/kmmz1q61p1a6mv1c8yw9wihmdakqlc11-cuda13.0-cuda_cccl-13.0.50-include/include/thrust/detail/config.h:22,
              #                  from /nix/store/kmmz1q61p1a6mv1c8yw9wihmdakqlc11-cuda13.0-cuda_cccl-13.0.50-include/include/thrust/tuple.h:32,
              #                  from /build/source/opencv_contrib/cudev/include/opencv2/cudev/util/detail/tuple.hpp:49,
              #                  from /build/source/opencv_contrib/cudev/include/opencv2/cudev/util/tuple.hpp:50,
              #                  from /build/source/opencv_contrib/cudev/include/opencv2/cudev.hpp:55,
              #                  from /build/source/opencv_contrib/cudev/test/test_precomp.hpp:47,
              #                  from /build/source/opencv_contrib/cudev/test/test_cmp_op.cu:44:
              # /nix/store/kmmz1q61p1a6mv1c8yw9wihmdakqlc11-cuda13.0-cuda_cccl-13.0.50-include/include/thrust/detail/config/cpp_dialect.h:78:6: error: #error Thrust requires at least C++17. Define CCCL_IGNORE_DEPRECATED_CPP_>
              #    78 | #    error Thrust requires at least C++17. Define CCCL_IGNORE_DEPRECATED_CPP_DIALECT to suppress this message.
              #       |      ^~~~~
              (final.lib.cmakeFeature "CUDA_NVCC_FLAGS" "-Wno-deprecated-declarations -DCCCL_IGNORE_DEPRECATED_CPP_DIALECT=1")
            ];
        }
      );

      # openmpi = prev.openmpi.override (prevAttrs: {
      #   cudaPackages = prevAttrs.cudaPackages // {
      #     # Nothing else should be changed, so we don't override the scope.
      #     cuda_cudart = cudartJoined;
      #   };
      # });

      ucx = prev.ucx.override (prevAttrs: {
        cudaPackages = prevAttrs.cudaPackages // {
          # Nothing else should be changed, so we don't override the scope.
          cuda_cudart = cudartJoined;
        };
      });

      ucc =
        (prev.ucc.override (prevAttrs: {
          # Use the joined nvcc package
          cudaPackages = prevAttrs.cudaPackages // {
            # Nothing else should be changed, so we don't override the scope.
            cuda_nvcc = nvccJoined;
          };
        })).overrideAttrs
          {
            env.LDFLAGS = builtins.toString [
              # Fake libnvidia-ml.so (the real one is deployed impurely)
              "-L${getOutput "stubs" final.cudaPackages.cuda_nvml_dev}/lib/stubs"
            ];
          };

      frei0r = prev.frei0r.overrideAttrs (prevAttrs: {
        # Missing cuda_nvcc in nativeBuildInputs
        nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
          final.cudaPackages.cuda_nvcc
        ];
        # Cannot have cuda_nvcc in both nativeBuildInputs and buildInputs wihout strictDeps being enabled.
        buildInputs = filter (drv: drv != final.cudaPackages.cuda_nvcc) prevAttrs.buildInputs;
        # Uses old, deprecated FindCUDA.cmake
        cmakeFlags = prevAttrs.cmakeFlags or [ ] ++ [
          (cmakeOptionType "PATH" "CUDA_TOOLKIT_ROOT_DIR" "${getBin final.cudaPackages.cuda_nvcc}")
        ];
      });

      onnxruntime = final.callPackage ./pkgs/development/libraries/onnxruntime {
        inherit (final.darwin.apple_sdk.frameworks) Foundation;
      };

      onnx-tensorrt = final.callPackage ./pkgs/development/libraries/onnx-tensorrt { };

      onnx = final.callPackage ./pkgs/development/libraries/onnx { };
    };
in
composeManyExtensions [
  extraAutoCalledPackages
  extraTesterPackages
  extraPythonPackages
  (import ./pkgs/top-level/cuda-packages.nix)
  extraPackages
] final' prev'
