{
  callPackages,
  isDeclaredArray,
  lib,
  makeSetupHook',
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook' {
  name = "arraysAreEqual";
  script = ./arraysAreEqual.bash;
  propagatedBuildInputs = [ isDeclaredArray ];
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Tests if two arrays are equal";
    maintainers = cuda.members;
  };
}
