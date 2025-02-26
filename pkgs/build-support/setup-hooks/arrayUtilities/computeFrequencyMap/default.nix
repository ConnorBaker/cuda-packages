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
  name = "compute-frequency-map";
  propagatedBuildInputs = [
    isDeclaredArray
    isDeclaredMap
  ];
  substitutions.functionGuard = functionGuard "computeFrequencyMap";
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Computes the frequency of each element in an array";
    maintainers = cuda.members;
  };
} ./computeFrequencyMap.sh
