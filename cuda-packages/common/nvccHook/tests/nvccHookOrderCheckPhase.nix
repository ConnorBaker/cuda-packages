# NOTE: Tests for nvccHookOrderCheckPhase go here.
{
  autoPatchelfHook,
  lib,
  nixLogWithLevelAndFunctionNameHook,
  nvccHook,
  stdenv,
  testers,
}:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (nvccHook.passthru.substitutions) nvccHostCCMatchesStdenvCC;
  inherit (testers) runCommand testBuildFailure;
in
# The ordering checks are only relevant when our host compiler is not the same as the standard environment's compiler.
optionalAttrs (!nvccHostCCMatchesStdenvCC) {
  no-autoPatchelfHook = stdenv.mkDerivation {
    __structuredAttrs = true;
    strictDeps = true;
    name = "no-autoPatchelfHook";
    src = null;
    dontUnpack = true;
    nativeBuildInputs = [ nvccHook ];
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
          nvccHook
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
        "ERROR: nvccHookOrderCheckPhase: autoPatchelfPostFixup must run before 'autoFixElfFiles nvccRunpathCheck'" \
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
      nvccHook
    ];
    installPhase = "touch $out";
  };
}
