{
  isDeclaredArray,
  lib,
  makeSetupHook',
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook' {
  name = "occursOnlyOrAfterInArray";
  script = ./occursOnlyOrAfterInArray.bash;
  scriptNativeBuildInputs = [ isDeclaredArray ];
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
}
