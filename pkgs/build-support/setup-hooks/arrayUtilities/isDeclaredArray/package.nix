{
  lib,
  makeBashFunction,
}:
let
  inherit (lib.teams) cuda;
in
makeBashFunction {
  name = "isDeclaredArray";
  script = ./isDeclaredArray.bash;
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
}
