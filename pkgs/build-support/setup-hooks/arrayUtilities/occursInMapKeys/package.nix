{
  isDeclaredMap,
  getMapKeys,
  lib,
  makeBashFunction,
  occursInArray,
}:
let
  inherit (lib.teams) cuda;
in
makeBashFunction {
  name = "occursInMapKeys";
  script = ./occursInMapKeys.bash;
  propagatedBuildInputs = [
    isDeclaredMap
    getMapKeys
    occursInArray
  ];
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
}
