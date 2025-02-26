{
  functionGuard,
  isDeclaredMap,
  lib,
  makeSetupHook,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook {
  name = "map-is-submap";
  propagatedBuildInputs = [ isDeclaredMap ];
  substitutions.functionGuard = functionGuard "mapIsSubmap";
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
} ./mapIsSubmap.sh
