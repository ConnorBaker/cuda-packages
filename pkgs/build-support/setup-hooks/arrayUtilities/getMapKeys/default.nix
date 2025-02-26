{
  functionGuard,
  isDeclaredArray,
  isDeclaredMap,
  lib,
  makeSetupHook,
  sortArray,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook {
  name = "get-map-keys";
  propagatedBuildInputs = [
    isDeclaredArray
    isDeclaredMap
    sortArray
  ];
  substitutions.functionGuard = functionGuard "getMapKeys";
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
} ./getMapKeys.sh
