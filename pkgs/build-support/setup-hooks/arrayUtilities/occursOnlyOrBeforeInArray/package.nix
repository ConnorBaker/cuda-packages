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
  name = "occursOnlyOrBeforeInArray";
  script = ./occursOnlyOrBeforeInArray.bash;
  propagatedBuildInputs = [ isDeclaredArray ];
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
}
