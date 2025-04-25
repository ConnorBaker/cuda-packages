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

  extraAutoCalledPackagesTests = final: prev: {
    tests = prev.tests // {
      deduplicateRunpathEntriesHook = final.deduplicateRunpathEntriesHook.passthru.tests;
    };
  };

  extraTesterPackages = final: prev: {
    testers = prev.testers // {
      makeMainWithRunpath = final.callPackage ./pkgs/build-support/testers/makeMainWithRunpath { };
      testRunpath = final.callPackage ./pkgs/build-support/testers/testRunpath { };
    };

    tests = prev.tests // {
      testers = prev.tests.testers // {
        makeMainWithRunpath =
          final.callPackages ./pkgs/build-support/testers/makeMainWithRunpath/tests.nix
            { };
        testRunpath = final.callPackages ./pkgs/build-support/testers/testRunpath/tests.nix { };
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
            # Cannot have cuda_nvcc in both nativeBuildInputs and buildInputs wihout strictDeps being enabled.
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
            # Cannot have cuda_nvcc in both nativeBuildInputs and buildInputs wihout strictDeps being enabled.
            buildInputs = filter (drv: drv != final.cudaPackages.cuda_nvcc) prevAttrs.buildInputs;
            # NOTE: "No CUDA runtime is found" is an expected message given we don't allow GPU access in the build.
            # TODO: https://github.com/state-spaces/mamba/blob/2e16fc3062cdcd4ebef27a9aa4442676e1c7edf4/setup.py#L175
            # TODO: https://github.com/state-spaces/mamba/blob/2e16fc3062cdcd4ebef27a9aa4442676e1c7edf4/setup.py#L44
            # TODO: https://github.com/state-spaces/mamba/blob/2e16fc3062cdcd4ebef27a9aa4442676e1c7edf4/setup.py#L282
            env = prevAttrs.env // {
              CUDA_HOME = "${getBin final.cudaPackages.cuda_nvcc}";
            };
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
                  ++ final.lib.optionals final.cudaPackages.nccl.meta.available [ final.cudaPackages.nccl.static ];

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
          "cupy"
          "modelopt"
          "modelopt-core"
          "nvcomp"
          "pycuda"
          "tensorrt"
          "warp"
        ] (name: finalPythonPackages.callPackage (./pkgs/development/python-modules + "/${name}") { })
      )
    ];
  };

  cudaPackages = import ./pkgs/top-level/cuda-packages.nix;

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
      openmpi = prev.openmpi.override (prevAttrs: {
        cudaPackages = prevAttrs.cudaPackages // {
          # Nothing else should be changed, so we don't override the scope.
          cuda_cudart = cudartJoined;
        };
      });

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

      # Example of disabling cuda_compat for JetPack 6
      # cudaPackagesExtensions = prev.cudaPackagesExtensions or [ ] ++ [ (_: _: { cuda_compat = null; }) ];
    };
in
composeManyExtensions [
  extraAutoCalledPackages
  extraAutoCalledPackagesTests
  extraTesterPackages
  extraPythonPackages
  cudaPackages
  extraPackages
] final' prev'
