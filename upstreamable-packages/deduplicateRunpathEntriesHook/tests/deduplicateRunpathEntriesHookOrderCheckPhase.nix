# NOTE: Tests for deduplicateRunpathEntriesHookOrderCheckPhase go here.
{
  autoPatchelfHook,
  cApplication,
  deduplicateRunpathEntriesHook,
  lib,
  runCommand,
  testers,
  ...
}:
let
  inherit (lib.strings) optionalString;
  inherit (testers) testBuildFailure;
in
{
  no-autoPatchelfHook = cApplication.overrideAttrs (prevAttrs: {
    name =
      "no-autoPatchelfHook" + optionalString (prevAttrs.__structuredAttrs or false) "-structuredAttrs";
    nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
      deduplicateRunpathEntriesHook
    ];
  });

  before-autoPatchelfHook =
    runCommand
      (
        "before-autoPatchelfHook"
        + optionalString (cApplication.__structuredAttrs or false) "-structuredAttrs"
      )
      {
        failed = testBuildFailure (
          cApplication.overrideAttrs (prevAttrs: {
            name =
              "before-autoPatchelfHook-inner"
              + optionalString (prevAttrs.__structuredAttrs or false) "-structuredAttrs";
            nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
              deduplicateRunpathEntriesHook
              autoPatchelfHook
            ];
          })
        );
      }
      ''
        echo "Checking for exit code 1" >&$NIX_LOG_FD
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        echo "Checking for error message" >&$NIX_LOG_FD
        grep -F \
          "ERROR: deduplicateRunpathEntriesHookOrderCheckPhase: autoPatchelfPostFixup must run before 'autoFixElfFiles deduplicateRunpathEntries'" \
          "$failed/testBuildFailure.log"
        echo "Test passed" >&$NIX_LOG_FD
        touch $out
      '';

  after-autoPatchelfHook = cApplication.overrideAttrs (prevAttrs: {
    name =
      "after-autoPatchelfHook" + optionalString (prevAttrs.__structuredAttrs or false) "-structuredAttrs";
    nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
      autoPatchelfHook
      deduplicateRunpathEntriesHook
    ];
  });
}
