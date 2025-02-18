# NOTE: Tests for cudaRunpathFixupHookOrderCheckPhase go here.
{
  autoAddDriverRunpath,
  autoPatchelfHook,
  cudaRunpathFixupHook,
  stdenv,
  testers,
}:
let
  inherit (testers) runCommand testBuildFailure;

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

  before-autoPatchelfHook-no-fixup = runCommand {
    name = "${cudaRunpathFixupHook.name}-before-autoPatchelfHook-no-fixup";
    failed = testBuildFailure (check {
      name = "before-autoPatchelfHook-no-fixup-inner";
      dontCudaRunpathFixHookOrder = true;
      nativeBuildInputs = [
        cudaRunpathFixupHook
        autoPatchelfHook
      ];
    });
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for error message"
      grep -F \
        "ERROR: cudaRunpathFixupHookOrderCheck: autoPatchelfPostFixup must run before 'autoFixElfFiles cudaRunpathFixup'" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
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

  before-autoAddDriverRunpath-no-fixup = runCommand {
    name = "${cudaRunpathFixupHook.name}-before-autoAddDriverRunpath-no-fixup";
    failed = testBuildFailure (check {
      name = "before-autoAddDriverRunpath-no-fixup-inner";
      dontCudaRunpathFixHookOrder = true;
      nativeBuildInputs = [
        cudaRunpathFixupHook
        autoAddDriverRunpath
      ];
    });
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for error message"
      grep -F \
        "ERROR: cudaRunpathFixupHookOrderCheck: 'autoFixElfFiles addDriverRunpath' must run before 'autoFixElfFiles cudaRunpathFixup'" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
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
