{
  callPackages,
  isDeclaredArray,
  lib,
  makeBashFunction,
  occursInArray,
}:
let
  inherit (lib.teams) cuda;
in
makeBashFunction {
  name = "arrayDifference";
  script = ./arrayDifference.bash;
  propagatedBuildInputs = [
    isDeclaredArray
    occursInArray
  ];
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Computes the difference of two arrays";
    maintainers = cuda.members;
  };
}
