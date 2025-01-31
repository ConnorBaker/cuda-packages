# NOTE: Tests for deduplicateRunpathEntriesHookOrderCheckPhase go here.
{
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
}
