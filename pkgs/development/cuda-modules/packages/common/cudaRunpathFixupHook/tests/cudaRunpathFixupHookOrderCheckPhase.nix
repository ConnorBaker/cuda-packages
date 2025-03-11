# NOTE: Tests for cudaRunpathFixupHookOrderCheckPhase go here.
{
  autoAddDriverRunpath,
  autoPatchelfHook,
  cudaRunpathFixupHook,
  stdenv,
  testers,
}:
let
  inherit (testers) testBuildFailure';

  check =
    drvArgs@{ name, ... }:
    stdenv.mkDerivation (
      {
        __structuredAttrs = true;
        strictDeps = true;
        name = "${cudaRunpathFixupHook.name}-${name}";
        src = null;
        dontUnpack = true;
        installPhase = "touch $out";
      }
      // builtins.removeAttrs drvArgs [ "name" ]
    );
in
{
  no-autoPatchelfHook = check {
    name = "no-autoPatchelfHook";
    nativeBuildInputs = [ cudaRunpathFixupHook ];
  };

  before-autoPatchelfHook-no-fixup = testBuildFailure' {
    name = "${cudaRunpathFixupHook.name}-before-autoPatchelfHook-no-fixup";
    drv = check {
      name = "before-autoPatchelfHook-no-fixup-inner";
      dontCudaRunpathFixHookOrder = true;
      nativeBuildInputs = [
        cudaRunpathFixupHook
        autoPatchelfHook
      ];
    };
    expectedBuilderLogEntries = [
      "ERROR: cudaRunpathFixupHookOrderCheck: autoPatchelfPostFixup must run before 'autoFixElfFiles cudaRunpathFixup'"
    ];
  };

  before-autoPatchelfHook-with-fixup = check {
    name = "before-autoPatchelfHook-with-fixup";
    nativeBuildInputs = [
      cudaRunpathFixupHook
      autoPatchelfHook
    ];
  };

  after-autoPatchelfHook = check {
    name = "after-autoPatchelfHook";
    nativeBuildInputs = [
      autoPatchelfHook
      cudaRunpathFixupHook
    ];
  };

  no-autoAddDriverRunpath = check {
    name = "no-autoAddDriverRunpath";
    nativeBuildInputs = [ cudaRunpathFixupHook ];
  };

  before-autoAddDriverRunpath-no-fixup = testBuildFailure' {
    name = "${cudaRunpathFixupHook.name}-before-autoAddDriverRunpath-no-fixup";
    drv = check {
      name = "before-autoAddDriverRunpath-no-fixup-inner";
      dontCudaRunpathFixHookOrder = true;
      nativeBuildInputs = [
        cudaRunpathFixupHook
        autoAddDriverRunpath
      ];
    };
    expectedBuilderLogEntries = [
      "ERROR: cudaRunpathFixupHookOrderCheck: 'autoFixElfFiles addDriverRunpath' must run before 'autoFixElfFiles cudaRunpathFixup'"
    ];
  };

  before-autoAddDriverRunpath-with-fixup = check {
    name = "before-autoAddDriverRunpath";
    nativeBuildInputs = [
      cudaRunpathFixupHook
      autoAddDriverRunpath
    ];
  };

  after-autoAddDriverRunpath = check {
    name = "after-autoAddDriverRunpath";
    nativeBuildInputs = [
      autoAddDriverRunpath
      cudaRunpathFixupHook
    ];
  };
}
