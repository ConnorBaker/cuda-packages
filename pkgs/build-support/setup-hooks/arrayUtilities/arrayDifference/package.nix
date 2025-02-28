{
  callPackages,
  isDeclaredArray,
  lib,
  makeSetupHook',
  occursInArray,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook' {
  name = "arrayDifference";
  script = ./arrayDifference.bash;
  scriptNativeBuildInputs = [
    isDeclaredArray
    occursInArray
  ];
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Computes the difference of two arrays";
    maintainers = cuda.members;
  };
}
