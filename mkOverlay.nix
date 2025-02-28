# This is largely a shim for Nixpkgs.
{ lib, nixpkgsSrc }:
let
  inherit (lib.attrsets)
    concatMapAttrs
    genAttrs
    optionalAttrs
    recurseIntoAttrs
    ;
  inherit (lib.customisation) callPackagesWith makeScope;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.fixedPoints) composeManyExtensions;

  extraAutoCalledPackages = import "${nixpkgsSrc}/pkgs/top-level/by-name-overlay.nix" ./pkgs/by-name;
  extraSetupHooks = final: prev: {
    arrayUtilities = makeScope final.newScope (
      finalArrayUtilities:
      recurseIntoAttrs {
        callPackages = callPackagesWith (final // finalArrayUtilities);
      }
      // packagesFromDirectoryRecursive {
        inherit (finalArrayUtilities) callPackage;
        directory = ./pkgs/build-support/setup-hooks/arrayUtilities;
      }
    );
    makeSetupHook' = final.callPackage ./pkgs/build-support/setup-hooks/makeSetupHookPrime { };
    runpathFixup = final.callPackage ./pkgs/build-support/setup-hooks/runpathFixup { };
    tests = prev.tests // {
      arrayUtilities = concatMapAttrs (
        name: value:
        optionalAttrs (value ? passthru.tests) {
          ${name} = value.passthru.tests;
        }
      ) final.arrayUtilities;
      # TODO: Add tests for makeSetupHook' and sourceGuard.bash.
    };
  };
  extraTesterPackages = final: prev: {
    testers = prev.testers // {
      shellcheck = final.callPackage ./pkgs/build-support/testers/shellcheck { };
      shfmt = final.callPackage ./pkgs/build-support/testers/shfmt { };
      testRunpath = import ./pkgs/build-support/testers/testRunpath {
        inherit (final) lib patchelf stdenvNoCC;
      };
    };
    tests = prev.tests // {
      testers = prev.tests.testers // {
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
in
composeManyExtensions [
  extraAutoCalledPackages
  extraTesterPackages
  extraSetupHooks
  extraPythonPackages
  cudaPackages
]

# # Package fixes
# // {
#   openmpi = prev.openmpi.override {
#     # The configure flag openmpi takes expects cuda_cudart to be joined.
#     cudaPackages = final.cudaPackages // {
#       cuda_cudart = final.symlinkJoin {
#         name = "cuda_cudart_joined";
#         paths = map (
#           output: final.cudaPackages.cuda_cudart.${output}
#         ) final.cudaPackages.cuda_cudart.outputs;
#       };
#     };
#   };
#   # https://github.com/NixOS/nixpkgs/blob/6c4e0724e0a785a20679b1bca3a46bfce60f05b6/pkgs/by-name/uc/ucc/package.nix#L36-L39
#   ucc = prev.ucc.overrideAttrs { strictDeps = false; };
# }
