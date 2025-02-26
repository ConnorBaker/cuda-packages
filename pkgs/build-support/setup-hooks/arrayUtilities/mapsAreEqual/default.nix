{
  functionGuard,
  isDeclaredMap,
  lib,
  makeSetupHook,
  mapIsSubmap,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook {
  name = "maps-are-equal";
  propagatedBuildInputs = [
    isDeclaredMap
    mapIsSubmap
  ];
  substitutions.functionGuard = functionGuard "mapsAreEqual";
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
} ./mapsAreEqual.sh
