{
  functionGuard,
  isDeclaredArray,
  lib,
  makeSetupHook,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook {
  name = "occurs-only-or-after-in-array";
  propagatedBuildInputs = [ isDeclaredArray ];
  substitutions.functionGuard = functionGuard "occursOnlyOrAfterInArray";
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
} ./occursOnlyOrAfterInArray.sh
