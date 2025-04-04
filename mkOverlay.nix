# This is largely a shim for Nixpkgs.
{ lib, nixpkgsSrc }:
let
  inherit (lib.attrsets) genAttrs;
  inherit (lib.fixedPoints) composeManyExtensions;

  extraAutoCalledPackages = import "${nixpkgsSrc}/pkgs/top-level/by-name-overlay.nix" ./pkgs/by-name;
  extraAutoCalledPackagesTests = final: prev: {
    tests = prev.tests // {
      deduplicateRunpathEntriesHook = final.deduplicateRunpathEntriesHook.passthru.tests;
    };
  };
  extraSetupHooks = final: prev: {
    runpathFixup = final.callPackage ./pkgs/build-support/setup-hooks/runpathFixup { };
    tests = prev.tests // {
      runpathFixup = final.runpathFixup.passthru.tests;
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
        finalPythonPackages: _:
        let
          inherit (finalPythonPackages) callPackage;
        in
        genAttrs [
          "onnx"
          "onnxruntime"
          "onnx-tensorrt"
          "pycuda"
          "tensorrt-python"
          "warp"
        ] (name: callPackage (./pkgs/development/python-modules + "/${name}") { })
      )
    ];
  };
  cudaPackages = import ./pkgs/top-level/cuda-packages.nix;
  packageFixes =
    final: prev:
    let
      useCudartJoined =
        drv:
        drv.override (prevAttrs: {
          cudaPackages = prevAttrs.cudaPackages // {
            # Nothing else should be changed, so we don't override the scope.
            cuda_cudart = final.symlinkJoin {
              name = "cudart-joined";
              paths = lib.concatMap (
                # Don't include the stubs in the joined package.
                output: lib.optionals (output != "stubs") [ prevAttrs.cudaPackages.cuda_cudart.${output} ]
              ) prevAttrs.cudaPackages.cuda_cudart.outputs;
            };
          };
        });
    in
    {
      ucc = useCudartJoined prev.ucc;
      ucx = useCudartJoined prev.ucx;
    };
in
composeManyExtensions [
  extraAutoCalledPackages
  extraAutoCalledPackagesTests
  extraTesterPackages
  extraSetupHooks
  extraPythonPackages
  cudaPackages
  packageFixes
]
