{
  isDeclaredArray,
  isDeclaredMap,
  lib,
  makeSetupHook',
  sortArray,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook' {
  name = "getMapKeys";
  script = ./getMapKeys.bash;
  propagatedBuildInputs = [
    isDeclaredArray
    isDeclaredMap
    sortArray
  ];
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
}
