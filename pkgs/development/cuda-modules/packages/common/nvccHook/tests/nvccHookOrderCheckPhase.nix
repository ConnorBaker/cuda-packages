# NOTE: Tests for nvccHookOrderCheckPhase go here.
{
  autoPatchelfHook,
  lib,
  nvccHook,
  stdenv,
  testers,
}:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (nvccHook.passthru.substitutions) nvccHostCCMatchesStdenvCC;
  inherit (testers) runCommand testBuildFailure;

  check =
    drvArgs@{ name, ... }:
    stdenv.mkDerivation (
      {
        __structuredAttrs = true;
        strictDeps = true;
        name = "${nvccHook.name}-${name}";
        src = null;
        dontUnpack = true;
        installPhase = "touch $out";
      }
      // builtins.removeAttrs drvArgs [ "name" ]
    );
in
# The ordering checks are only relevant when our host compiler is not the same as the standard environment's compiler.
optionalAttrs (!nvccHostCCMatchesStdenvCC) {
  no-autoPatchelfHook = check {
    name = "no-autoPatchelfHook";
    nativeBuildInputs = [ nvccHook ];
  };

  before-autoPatchelfHook-no-fixup = runCommand {
    name = "${nvccHook.name}-before-autoPatchelfHook-no-fixup";
    failed = testBuildFailure (check {
      name = "before-autoPatchelfHook-no-fixup-inner";
      dontNvccFixHookOrder = true;
      nativeBuildInputs = [
        nvccHook
        autoPatchelfHook
      ];
    });
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for error message"
      grep -F \
        "ERROR: nvccHookOrderCheck: autoPatchelfPostFixup must run before 'autoFixElfFiles nvccRunpathCheck'" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  before-autoPatchelfHook-with-fixup = check {
    name = "before-autoPatchelfHook-with-fixup";
    nativeBuildInputs = [
      nvccHook
      autoPatchelfHook
    ];
  };

  after-autoPatchelfHook = check {
    name = "after-autoPatchelfHook";
    nativeBuildInputs = [
      autoPatchelfHook
      nvccHook
    ];
  };
}
