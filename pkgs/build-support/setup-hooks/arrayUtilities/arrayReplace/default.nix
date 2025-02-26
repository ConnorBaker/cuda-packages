{
  callPackages,
  functionGuard,
  lib,
  makeSetupHook,
  isDeclaredArray,
  isDeclaredMap,
  occursInMapKeys,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook {
  name = "array-replace";
  propagatedBuildInputs = [
    isDeclaredArray
    isDeclaredMap
    occursInMapKeys
  ];
  substitutions.functionGuard = functionGuard "arrayReplace";
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Replaces all occurrences of a value in an array with other value(s)";
    maintainers = cuda.members;
  };
} ./arrayReplace.sh
