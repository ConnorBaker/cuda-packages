{
  functionGuard,
  lib,
  makeSetupHook,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook {
  name = "is-declared-map";
  substitutions.functionGuard = functionGuard "isDeclaredMap";
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
} ./isDeclaredMap.sh
