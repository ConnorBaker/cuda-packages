let
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

  extraPythonPackages =
    final: prev:
    let
      pythonPackagesExtension = finalPythonPackages: prevPythonPackages: {
        # causal-conv1d = prevPythonPackages.causal-conv1d.overrideAttrs (prevAttrs: {
        #   # Missing cuda_nvcc in nativeBuildInputs
        #   nativeBuildInputs = prevAttrs.nativeBuildInputs ++ [ final.cudaPackages.cuda_nvcc ];
        #   # Cannot have cuda_nvcc in both nativeBuildInputs and buildInputs without strictDeps being enabled.
        #   buildInputs = filter (drv: drv != final.cudaPackages.cuda_nvcc) prevAttrs.buildInputs;
        #   # TODO: https://github.com/Dao-AILab/causal-conv1d/blob/82867a9d2e6907cc0f637ac6aff318f696838548/setup.py#L40
        #   # TODO: https://github.com/Dao-AILab/causal-conv1d/blob/82867a9d2e6907cc0f637ac6aff318f696838548/setup.py#L173
        #   # TODO: https://github.com/Dao-AILab/causal-conv1d/blob/82867a9d2e6907cc0f637ac6aff318f696838548/setup.py#L267
        #   # NOTE: "No CUDA runtime is found" is an expected message given we don't allow GPU access in the build.
        #   env = prevAttrs.env // {
        #     CUDA_HOME = "${getBin final.cudaPackages.cuda_nvcc}";
        #   };
        # });

        # mamba-ssm = prevPythonPackages.mamba-ssm.overrideAttrs (prevAttrs: {
        #   # Missing cuda_nvcc in nativeBuildInputs
        #   nativeBuildInputs = prevAttrs.nativeBuildInputs ++ [ final.cudaPackages.cuda_nvcc ];
        #   # Cannot have cuda_nvcc in both nativeBuildInputs and buildInputs without strictDeps being enabled.
        #   buildInputs = filter (drv: drv != final.cudaPackages.cuda_nvcc) prevAttrs.buildInputs;
        #   # NOTE: "No CUDA runtime is found" is an expected message given we don't allow GPU access in the build.
        #   # TODO: https://github.com/state-spaces/mamba/blob/2e16fc3062cdcd4ebef27a9aa4442676e1c7edf4/setup.py#L175
        #   # TODO: https://github.com/state-spaces/mamba/blob/2e16fc3062cdcd4ebef27a9aa4442676e1c7edf4/setup.py#L44
        #   # TODO: https://github.com/state-spaces/mamba/blob/2e16fc3062cdcd4ebef27a9aa4442676e1c7edf4/setup.py#L282
        #   env = prevAttrs.env // {
        #     CUDA_HOME = "${getBin final.cudaPackages.cuda_nvcc}";
        #   };
        # });

        # # Fails due to distutils missing.
        # # NOTE: Why does it take overridePythonAttrs to make this work?
        # mmengine = prevPythonPackages.mmengine.overridePythonAttrs { doCheck = false; };

        # mmcv = prevPythonPackages.mmcv.overridePythonAttrs (prevAttrs: {
        #   # CUDA_HOME is only expected to contain a working nvcc in /bin.
        #   env.CUDA_HOME = final.lib.optionalString finalPythonPackages.torch.cudaSupport "${final.lib.getBin final.cudaPackages.cuda_nvcc}";
        #   # Fails due to distutils missing.
        #   disabledTests = prevAttrs.disabledTests ++ [ "test_env" ];
        # });

        # torch =
        #   # Could not find CUPTI library, using CPU-only Kineto build
        #   # Could NOT find NCCL (missing: NCCL_INCLUDE_DIR)
        #   # USE_TENSORRT is unset in the printed config at the end of configurePhase.
        #   # Not sure if that's used directly or passed through to one of the vendored projects.
        #   (prevPythonPackages.torch.override {
        #     # PyTorch doesn't need Triton to build.
        #     # Just include it in whichever package consumes pytorch.
        #     tritonSupport = false;
        #   }).overrideAttrs
        #     (prevAttrs: {
        #       buildInputs =
        #         prevAttrs.buildInputs or [ ]
        #         ++ [
        #           final.cudaPackages.libcusparse_lt
        #           final.cudaPackages.libcudss
        #           final.cudaPackages.libcufile
        #         ]
        #         ++ optionals final.cudaPackages.nccl.meta.available [ final.cudaPackages.nccl.static ];

        #       USE_CUFILE = 1;
        #     });

        # triton = prevPythonPackages.triton.overrideAttrs (
        #   let
        #     inherit (final.stdenv) cc;
        #   in
        #   finalAttrs: prevAttrs: {
        #     env = prevAttrs.env or { } // {
        #       CC = "${cc}/bin/${cc.targetPrefix}cc";
        #       CXX = "${cc}/bin/${cc.targetPrefix}c++";
        #     };
        #     preConfigure =
        #       prevAttrs.preConfigure or ""
        #       # Patch in our compiler.
        #       # https://github.com/triton-lang/triton/blob/cf34004b8a67d290a962da166f5aa2fc66751326/python/triton/runtime/build.py#L25
        #       + ''
        #         substituteInPlace "$NIX_BUILD_TOP/$sourceRoot/python/triton/runtime/build.py" \
        #           --replace-fail \
        #             'cc = os.environ.get("CC")' \
        #             'cc = "${finalAttrs.env.CC}"'
        #       '';
        #   }
        # );

        # onnxruntime = finalPythonPackages.callPackage ./pkgs/development/python-modules/onnxruntime {
        #   onnxruntime = final.onnxruntime.override {
        #     python3Packages = finalPythonPackages;
        #     pythonSupport = true;
        #   };
        # };

        onnx-tensorrt = finalPythonPackages.callPackage ./pkgs/development/python-modules/onnx-tensorrt {
          onnx-tensorrt = final.onnx-tensorrt.override { python3Packages = finalPythonPackages; };
        };

        onnx = finalPythonPackages.callPackage ./pkgs/development/python-modules/onnx {
          onnx = final.onnx.override { python3Packages = finalPythonPackages; };
        };

        tensorrt = finalPythonPackages.callPackage ./pkgs/development/python-modules/tensorrt {
        };
      }
      # // final.lib.genAttrs [
      #   "bitsandbytes"
      #   "codetr"
      #   "cuda-bindings"
      #   "cuda-python"
      #   "cupy"
      #   "cutlass"
      #   "flash-attn"
      #   "mmdet"
      #   "modelopt"
      #   "modelopt-core"
      #   "nvcomp"
      #   "nvdlfw-inspect"
      #   "pyclibrary"
      #   "pycuda"
      #   "pyglove"
      #   "schedulefree"
      #   "tensorrt"
      #   "torch-tensorrt"
      #   "transformer-engine"
      #   "warp"
      # ] (name: finalPythonPackages.callPackage (./pkgs/development/python-modules + "/${name}") { });
      ;
    in
    {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [ pythonPackagesExtension ];
    };

  extraPackages = final: prev: {
    # NOTE: opencv is an alias to opencv4; make sure to override the actual derivation and not the alias.
    opencv4 = prev.opencv4.overrideAttrs (
      let
        contribSrc = final.fetchFromGitHub {
          owner = "opencv";
          repo = "opencv_contrib";
          rev = "5556eec08d3d9b08d5d276cab272e142ca85a271"; # Latest as of 2025-11-19
          hash = "sha256-ltk7pTelgBYoQ8SzYku7SEF0wm3QHaWzF+Fsln9OQ7A=";
        };
      in
      finalAttrs: prevAttrs: {
        src = final.fetchFromGitHub {
          owner = "opencv";
          repo = "opencv";
          rev = "8fb0b7177fc082bc726bb8739dc035baf8393b95"; # Latest as of 2025-11-19
          hash = "sha256-jSdGwTMUvYzV0nzCTPUu8YXau/ay6y8fNV0Hlv9oIlE=";
        };

        # NOTE: 4.12 doesn't work with CUDA 13.0.
        # There are a number of upstream PRs required, including at least
        # https://github.com/opencv/opencv/pull/27636.
        version = "4.12.0-unstable-2025-11-19";

        # Replace the exisiting postUnpack:
        # https://github.com/NixOS/nixpkgs/blob/5a4a475519ab311a5aedd816fac79641c806ff46/pkgs/development/libraries/opencv/4.x.nix#L294-L296
        # NOTE: No need to gate on `buildContrib` since the logic which adds it to the build is done in `preConfigure`,
        # regardless of its presence in the source.
        postUnpack = ''
          cp --no-preserve=mode -r "${contribSrc}/modules" "$NIX_BUILD_TOP/source/opencv_contrib"
        '';
      }
    );

    # onnxruntime = final.callPackage ./pkgs/development/libraries/onnxruntime {
    #   inherit (final.darwin.apple_sdk.frameworks) Foundation;
    # };
  };

  extraCudaPackages = final: prev: {
    _cuda = prev._cuda.extend (
      finalCuda: prevCuda: {
        extensions = [
          (finalCudaPackages: prevCudaPackages: {
            # NOTE:
            #
            #   Not including:
            #
            #     - cudaHook
            #     - markForCudaToolkitRootHook
            #     - nvccHook
            #
            #   These may not interact well with upstream's hooks and should be redesigned.

            # Newer than upstream
            cudnn-frontend =
              finalCudaPackages.callPackage ./pkgs/development/cuda-modules/packages/cudnn-frontend.nix
                { };
          })
        ];
      }
    );
  };
in

builtins.foldl'
  # Definition of extension composition
  # NOTE: Extension composition on extensions is a group, so we can use foldl' instead of lib.foldr.
  (
    f: g: final: prev:
    let
      fApplied = f final prev;
      prev' = prev // fApplied;
    in
    fApplied // g final prev'
  )
  # Identity extension
  (final: prev: { })
  [
    extraAutoCalledPackages
    extraCudaPackages
    extraTesterPackages
    extraPackages
    extraPythonPackages
  ]
