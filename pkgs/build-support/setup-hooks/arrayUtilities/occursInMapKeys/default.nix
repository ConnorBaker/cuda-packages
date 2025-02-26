{
  functionGuard,
  isDeclaredMap,
  getMapKeys,
  lib,
  makeSetupHook,
  occursInArray,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook {
  name = "occurs-in-map-keys";
  propagatedBuildInputs = [
    isDeclaredMap
    getMapKeys
    occursInArray
  ];
  substitutions.functionGuard = functionGuard "occursInMapKeys";
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
} ./occursInMapKeys.sh
