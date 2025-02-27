{
  isDeclaredMap,
  lib,
  makeSetupHook',
  mapIsSubmap,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook' {
  name = "mapsAreEqual";
  script = ./mapsAreEqual.bash;
  propagatedBuildInputs = [
    isDeclaredMap
    mapIsSubmap
  ];
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
}
