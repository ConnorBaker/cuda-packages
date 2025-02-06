# NOTE: Tests for deduplicateRunpathEntriesHookOrderCheckPhase go here.
{
  autoAddDriverRunpath,
  deduplicateRunpathEntriesHook,
  stdenv,
  testers,
}:
let
  inherit (testers) runCommand testBuildFailure;
in
{
  no-autoAddDriverRunpath = stdenv.mkDerivation {
    name = "no-autoAddDriverRunpath";
    src = null;
    dontUnpack = true;
    nativeBuildInputs = [ deduplicateRunpathEntriesHook ];
    installPhase = "touch $out";
  };

  before-autoAddDriverRunpath-no-fixup = runCommand {
    name = "before-autoAddDriverRunpath-no-fixup";
    failed = testBuildFailure (
      stdenv.mkDerivation {
        name = "before-autoAddDriverRunpath-no-fixup";
        src = null;
        dontUnpack = true;
        dontDeduplicateRunpathEntriesFixHookOrder = true;
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
        "ERROR: deduplicateRunpathEntriesHookOrderCheck: 'autoFixElfFiles addDriverRunpath' must run before 'autoFixElfFiles deduplicateRunpathEntries'" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  before-autoAddDriverRunpath-with-fixup = stdenv.mkDerivation {
    name = "before-autoAddDriverRunpath-with-fixup";
    src = null;
    dontUnpack = true;
    nativeBuildInputs = [
      deduplicateRunpathEntriesHook
      autoAddDriverRunpath
    ];
    installPhase = "touch $out";
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
