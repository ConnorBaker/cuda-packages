{
  isDeclaredArray,
  lib,
  makeBashFunction,
}:
let
  inherit (lib.teams) cuda;
in
makeBashFunction {
  name = "occursInArray";
  script = ./occursInArray.bash;
  propagatedBuildInputs = [ isDeclaredArray ];
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
}
