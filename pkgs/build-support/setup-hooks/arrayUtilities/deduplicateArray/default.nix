{
  callPackages,
  functionGuard,
  isDeclaredArray,
  isDeclaredMap,
  lib,
  makeSetupHook,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook {
  name = "deduplicate-array";
  propagatedBuildInputs = [
    isDeclaredArray
    isDeclaredMap
  ];
  substitutions.functionGuard = functionGuard "deduplicateArray";
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Removes duplicate elements from an array";
    maintainers = cuda.members;
  };
} ./deduplicateArray.sh
