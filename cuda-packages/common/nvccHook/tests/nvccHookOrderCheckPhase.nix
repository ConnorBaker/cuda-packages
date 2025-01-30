# NOTE: Tests for nvccHookOrderCheckPhase go here.
{
  autoPatchelfHook,
  cApplication,
  lib,
  nvccHook,
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
      nvccHook
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
              nvccHook
              autoPatchelfHook
            ];
          })
        );
      }
      ''
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        grep -F \
          "ERROR: nvccHookOrderCheckPhase: autoPatchelfPostFixup must run before 'autoFixElfFiles nvccRunpathCheck'" \
          "$failed/testBuildFailure.log"
        touch $out
      '';

  after-autoPatchelfHook = cApplication.overrideAttrs (prevAttrs: {
    name =
      "after-autoPatchelfHook" + optionalString (prevAttrs.__structuredAttrs or false) "-structuredAttrs";
    nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
      autoPatchelfHook
      nvccHook
    ];
  });
}
