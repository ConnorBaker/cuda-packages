{
  isDeclaredMap,
  lib,
  makeBashFunction,
}:
let
  inherit (lib.teams) cuda;
in
makeBashFunction {
  name = "mapIsSubmap";
  script = ./mapIsSubmap.bash;
  propagatedBuildInputs = [ isDeclaredMap ];
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
}
