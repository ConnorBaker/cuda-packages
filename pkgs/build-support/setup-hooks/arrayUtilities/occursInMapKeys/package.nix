{
  isDeclaredMap,
  getMapKeys,
  lib,
  makeSetupHook',
  occursInArray,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook' {
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
