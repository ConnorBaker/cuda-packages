{
  callPackages,
  isDeclaredArray,
  isDeclaredMap,
  lib,
  makeBashFunction,
}:
let
  inherit (lib.teams) cuda;
in
makeBashFunction {
  name = "computeFrequencyMap";
  script = ./computeFrequencyMap.bash;
  propagatedBuildInputs = [
    isDeclaredArray
    isDeclaredMap
  ];
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Computes the frequency of each element in an array";
    maintainers = cuda.members;
  };
}
