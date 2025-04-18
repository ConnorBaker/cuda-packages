# This is largely a shim for Nixpkgs.
final': prev':
let
  inherit (prev'.lib.attrsets) genAttrs getOutput;
  inherit (prev'.lib.lists) concatMap map optionals;
  inherit (prev'.lib.fixedPoints) composeManyExtensions;

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

  extraPythonPackages = _: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions or [ ] ++ [
      (
        finalPythonPackages: _:
        let
          inherit (finalPythonPackages) callPackage;
        in
        genAttrs [
          "onnx"
          "onnxruntime"
          "onnx-tensorrt"
          "pycuda"
          "tensorrt"
          "warp"
        ] (name: callPackage (./pkgs/development/python-modules + "/${name}") { })
      )
    ];
  };

  cudaPackages = import ./pkgs/top-level/cuda-packages.nix;

  packageFixes =
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
      mpi = prev.mpi.override (prevAttrs: {
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
  packageFixes
] final' prev'
