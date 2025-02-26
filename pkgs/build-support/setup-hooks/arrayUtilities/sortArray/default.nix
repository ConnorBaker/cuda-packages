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
  name = "sort-array";
  propagatedBuildInputs = [ isDeclaredArray ];
  substitutions.functionGuard = functionGuard "sortArray";
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
} ./sortArray.sh
