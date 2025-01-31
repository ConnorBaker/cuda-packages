# NOTE: Tests for cudaRunpathFixupHookOrderCheckPhase go here.
{
  autoAddDriverRunpath,
  autoPatchelfHook,
  nixLogWithLevelAndFunctionNameHook,
  cudaRunpathFixupHook,
  stdenv,
  testers,
}:
let
  inherit (testers) runCommand testBuildFailure;
in
{
  no-autoPatchelfHook = stdenv.mkDerivation {
    __structuredAttrs = true;
    strictDeps = true;
    name = "no-autoPatchelfHook";
    src = null;
    dontUnpack = true;
    nativeBuildInputs = [ cudaRunpathFixupHook ];
    installPhase = "touch $out";
  };

  before-autoPatchelfHook = runCommand {
    name = "before-autoPatchelfHook";
    nativeBuildInputs = [ nixLogWithLevelAndFunctionNameHook ];
    failed = testBuildFailure (
      stdenv.mkDerivation {
        __structuredAttrs = true;
        strictDeps = true;
        name = "before-autoPatchelfHook";
        src = null;
        dontUnpack = true;
        nativeBuildInputs = [
          cudaRunpathFixupHook
          autoPatchelfHook
        ];
        installPhase = "touch $out";
      }
    );
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for error message"
      grep -F \
        "ERROR: cudaRunpathFixupHookOrderCheckPhase: autoPatchelfPostFixup must run before 'autoFixElfFiles cudaRunpathFixup'" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  after-autoPatchelfHook = stdenv.mkDerivation {
    __structuredAttrs = true;
    strictDeps = true;
    name = "after-autoPatchelfHook";
    src = null;
    dontUnpack = true;
    nativeBuildInputs = [
      autoPatchelfHook
      cudaRunpathFixupHook
    ];
    installPhase = "touch $out";
  };

  no-autoAddDriverRunpath = stdenv.mkDerivation {
    __structuredAttrs = true;
    strictDeps = true;
    name = "no-autoAddDriverRunpath";
    src = null;
    dontUnpack = true;
    nativeBuildInputs = [ cudaRunpathFixupHook ];
    installPhase = "touch $out";
  };

  before-autoAddDriverRunpath = runCommand {
    name = "before-autoAddDriverRunpath";
    nativeBuildInputs = [ nixLogWithLevelAndFunctionNameHook ];
    failed = testBuildFailure (
      stdenv.mkDerivation {
        __structuredAttrs = true;
        strictDeps = true;
        name = "before-autoAddDriverRunpath";
        src = null;
        dontUnpack = true;
        nativeBuildInputs = [
          cudaRunpathFixupHook
          autoAddDriverRunpath
        ];
        installPhase = "touch $out";
      }
    );
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for error message"
      grep -F \
        "ERROR: cudaRunpathFixupHookOrderCheckPhase: 'autoFixElfFiles addDriverRunpath' must run before 'autoFixElfFiles cudaRunpathFixup'" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  after-autoAddDriverRunpath = stdenv.mkDerivation {
    __structuredAttrs = true;
    strictDeps = true;
    name = "after-autoAddDriverRunpath";
    src = null;
    dontUnpack = true;
    nativeBuildInputs = [
      autoAddDriverRunpath
      cudaRunpathFixupHook
    ];
    installPhase = "touch $out";
  };
}
