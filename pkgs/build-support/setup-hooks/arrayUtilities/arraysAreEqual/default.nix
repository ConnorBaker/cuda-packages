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
  name = "arrays-are-equal";
  propagatedBuildInputs = [ isDeclaredArray ];
  substitutions.functionGuard = functionGuard "arraysAreEqual";
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Tests if two arrays are equal";
    maintainers = cuda.members;
  };
} ./arraysAreEqual.sh
