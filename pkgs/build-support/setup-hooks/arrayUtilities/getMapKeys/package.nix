{
  isDeclaredArray,
  isDeclaredMap,
  lib,
  makeBashFunction,
  sortArray,
}:
let
  inherit (lib.teams) cuda;
in
makeBashFunction {
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
