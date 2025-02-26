{
  functionGuard,
  lib,
  makeSetupHook,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook {
  name = "is-declared-array";
  substitutions.functionGuard = functionGuard "isDeclaredArray";
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
} ./isDeclaredArray.sh
