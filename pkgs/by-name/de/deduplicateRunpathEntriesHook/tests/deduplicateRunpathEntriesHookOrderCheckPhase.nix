# NOTE: Tests for deduplicateRunpathEntriesHookOrderCheckPhase go here.
{
  autoAddDriverRunpath,
  deduplicateRunpathEntriesHook,
  lib,
  stdenv,
  testers,
}:
let
  inherit (testers) testBuildFailure';
in
lib.recurseIntoAttrs {
  no-autoAddDriverRunpath = stdenv.mkDerivation {
    name = "no-autoAddDriverRunpath";
    src = null;
    dontUnpack = true;
    nativeBuildInputs = [ deduplicateRunpathEntriesHook ];
    installPhase = "touch $out";
  };

  before-autoAddDriverRunpath-no-fixup = testBuildFailure' {
    drv = stdenv.mkDerivation {
      name = "before-autoAddDriverRunpath-no-fixup";
      src = null;
      dontUnpack = true;
      dontDeduplicateRunpathEntriesFixHookOrder = true;
      nativeBuildInputs = [
        deduplicateRunpathEntriesHook
        autoAddDriverRunpath
      ];
      installPhase = "touch $out";
    };
    expectedBuilderLogEntries = [
      "ERROR: deduplicateRunpathEntriesHookOrderCheck: 'autoFixElfFiles addDriverRunpath' must run before 'autoFixElfFiles deduplicateRunpathEntries'"
    ];
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
