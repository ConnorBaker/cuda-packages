{
  callPackages,
  isDeclaredArray,
  isDeclaredMap,
  lib,
  makeSetupHook',
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook' {
  name = "computeFrequencyMap";
  script = ./computeFrequencyMap.bash;
  scriptNativeBuildInputs = [
    isDeclaredArray
    isDeclaredMap
  ];
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Computes the frequency of each element in an array";
    maintainers = cuda.members;
  };
}
