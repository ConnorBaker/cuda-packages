# NOTE: Tests for deduplicateRunpathEntriesHookOrderCheckPhase go here.
{
  autoAddDriverRunpath,
  autoPatchelfHook,
  deduplicateRunpathEntriesHook,
  nixLogWithLevelAndFunctionNameHook,
  stdenv,
  testers,
}:
let
  inherit (testers) runCommand testBuildFailure;
in
{
  no-autoPatchelfHook = stdenv.mkDerivation {
    name = "no-autoPatchelfHook";
    src = null;
    dontUnpack = true;
    nativeBuildInputs = [ deduplicateRunpathEntriesHook ];
    installPhase = "touch $out";
  };

  before-autoPatchelfHook = runCommand {
    name = "before-autoPatchelfHook";
    nativeBuildInputs = [ nixLogWithLevelAndFunctionNameHook ];
    failed = testBuildFailure (
      stdenv.mkDerivation {
        name = "before-autoPatchelfHook";
        src = null;
        dontUnpack = true;
        nativeBuildInputs = [
          deduplicateRunpathEntriesHook
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
        "ERROR: deduplicateRunpathEntriesHookOrderCheckPhase: autoPatchelfPostFixup must run before 'autoFixElfFiles deduplicateRunpathEntries'" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  after-autoPatchelfHook = stdenv.mkDerivation {
    name = "after-autoPatchelfHook";
    src = null;
    dontUnpack = true;
    nativeBuildInputs = [
      autoPatchelfHook
      deduplicateRunpathEntriesHook
    ];
    installPhase = "touch $out";
  };

  no-autoAddDriverRunpath = stdenv.mkDerivation {
    name = "no-autoAddDriverRunpath";
    src = null;
    dontUnpack = true;
    nativeBuildInputs = [ deduplicateRunpathEntriesHook ];
    installPhase = "touch $out";
  };

  before-autoAddDriverRunpath = runCommand {
    name = "before-autoAddDriverRunpath";
    nativeBuildInputs = [ nixLogWithLevelAndFunctionNameHook ];
    failed = testBuildFailure (
      stdenv.mkDerivation {
        name = "before-autoAddDriverRunpath";
        src = null;
        dontUnpack = true;
        nativeBuildInputs = [
          deduplicateRunpathEntriesHook
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
        "ERROR: deduplicateRunpathEntriesHookOrderCheckPhase: 'autoFixElfFiles addDriverRunpath' must run before 'autoFixElfFiles deduplicateRunpathEntries'" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  after-autoAddDriverRunpath = stdenv.mkDerivation {
    name = "after-autoAddDriverRunpath";
    src = null;
    dontUnpack = true;
    nativeBuildInputs = [
      autoAddDriverRunpath
      deduplicateRunpathEntriesHook
    ];
    installPhase = "touch $out";
  };
}
