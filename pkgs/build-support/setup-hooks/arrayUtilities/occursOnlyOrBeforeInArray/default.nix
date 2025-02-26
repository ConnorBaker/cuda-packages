{
  callPackages,
  functionGuard,
  isDeclaredArray,
  lib,
  makeSetupHook,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook {
  name = "occurs-only-or-before-in-array";
  propagatedBuildInputs = [ isDeclaredArray ];
  substitutions.functionGuard = functionGuard "occursOnlyOrBeforeInArray";
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
} ./occursOnlyOrBeforeInArray.sh
