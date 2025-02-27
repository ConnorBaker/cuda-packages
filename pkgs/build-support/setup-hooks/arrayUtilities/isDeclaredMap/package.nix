{
  lib,
  makeBashFunction,
}:
let
  inherit (lib.teams) cuda;
in
makeBashFunction {
  name = "isDeclaredMap";
  script = ./isDeclaredMap.bash;
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
}
