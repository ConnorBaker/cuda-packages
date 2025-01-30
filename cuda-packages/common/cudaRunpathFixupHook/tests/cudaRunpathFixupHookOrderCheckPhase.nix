# NOTE: Tests for cudaRunpathFixupHookOrderCheckPhase go here.
{
  autoAddDriverRunpath,
  autoPatchelfHook,
  cApplication,
  cudaRunpathFixupHook,
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
      cudaRunpathFixupHook
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
              cudaRunpathFixupHook
              autoPatchelfHook
            ];
          })
        );
      }
      ''
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        grep -F \
          "ERROR: cudaRunpathFixupHookOrderCheckPhase: autoPatchelfPostFixup must run before 'autoFixElfFiles cudaRunpathFixup'" \
          "$failed/testBuildFailure.log"
        touch $out
      '';

  after-autoPatchelfHook = cApplication.overrideAttrs (prevAttrs: {
    name =
      "after-autoPatchelfHook" + optionalString (prevAttrs.__structuredAttrs or false) "-structuredAttrs";
    nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
      autoPatchelfHook
      cudaRunpathFixupHook
    ];
  });

  no-autoAddDriverRunpath = cApplication.overrideAttrs (prevAttrs: {
    name =
      "no-autoAddDriverRunpath"
      + optionalString (prevAttrs.__structuredAttrs or false) "-structuredAttrs";
    nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
      cudaRunpathFixupHook
    ];
  });

  before-autoAddDriverRunpath =
    runCommand
      (
        "before-autoAddDriverRunpath"
        + optionalString (cApplication.__structuredAttrs or false) "-structuredAttrs"
      )
      {
        failed = testBuildFailure (
          cApplication.overrideAttrs (prevAttrs: {
            name =
              "before-autoAddDriverRunpath-inner"
              + optionalString (prevAttrs.__structuredAttrs or false) "-structuredAttrs";
            nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
              cudaRunpathFixupHook
              autoAddDriverRunpath
            ];
          })
        );
      }
      ''
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        grep -F \
          "ERROR: cudaRunpathFixupHookOrderCheckPhase: 'autoFixElfFiles addDriverRunpath' must run before 'autoFixElfFiles cudaRunpathFixup'" \
          "$failed/testBuildFailure.log"
        touch $out
      '';

  after-autoAddDriverRunpath = cApplication.overrideAttrs (prevAttrs: {
    name =
      "after-autoAddDriverRunpath"
      + optionalString (prevAttrs.__structuredAttrs or false) "-structuredAttrs";
    nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
      autoAddDriverRunpath
      cudaRunpathFixupHook
    ];
  });
}
