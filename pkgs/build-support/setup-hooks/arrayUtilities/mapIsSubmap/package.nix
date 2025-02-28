{
  isDeclaredMap,
  lib,
  makeSetupHook',
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook' {
  name = "mapIsSubmap";
  script = ./mapIsSubmap.bash;
  scriptNativeBuildInputs = [ isDeclaredMap ];
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
}
