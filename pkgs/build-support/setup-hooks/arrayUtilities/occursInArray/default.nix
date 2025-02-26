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
  name = "occurs-in-array";
  propagatedBuildInputs = [ isDeclaredArray ];
  substitutions.functionGuard = functionGuard "occursInArray";
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
} ./occursInArray.sh
