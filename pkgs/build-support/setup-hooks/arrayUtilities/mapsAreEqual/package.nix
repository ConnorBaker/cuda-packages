{
  isDeclaredMap,
  lib,
  makeBashFunction,
  mapIsSubmap,
}:
let
  inherit (lib.teams) cuda;
in
makeBashFunction {
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
