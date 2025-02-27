{
  callPackages,
  lib,
  makeBashFunction,
  isDeclaredArray,
  isDeclaredMap,
  occursInMapKeys,
}:
let
  inherit (lib.teams) cuda;
in
makeBashFunction {
  name = "arrayReplace";
  script = ./arrayReplace.bash;
  propagatedBuildInputs = [
    isDeclaredArray
    isDeclaredMap
    occursInMapKeys
  ];
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Replaces all occurrences of a value in an array with other value(s)";
    maintainers = cuda.members;
  };
}
