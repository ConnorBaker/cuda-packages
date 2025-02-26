{
  callPackages,
  functionGuard,
  isDeclaredArray,
  lib,
  makeSetupHook,
  occursInArray,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook {
  name = "array-difference";
  propagatedBuildInputs = [
    isDeclaredArray
    occursInArray
  ];
  substitutions.functionGuard = functionGuard "arrayDifference";
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Computes the difference of two arrays";
    maintainers = cuda.members;
  };
} ./arrayDifference.sh
