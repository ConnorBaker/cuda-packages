{
  lib,
  makeSetupHook,
}:
makeSetupHook {
  name = "nix-log-with-level-and-function-name-hook";
  meta = {
    description = "Replaces logging functions declared in setup.sh with ones which log level and caller function name";
    maintainers = lib.teams.cuda.members;
  };
} ./nix-log-with-level-and-function-name-hook.sh
