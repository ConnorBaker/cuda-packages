{
  lib,
  makeSetupHook,
}:
makeSetupHook {
  name = "no-broken-symlinks-hook";
  meta = {
    description = "Checks for broken symlinks within outputs";
    maintainers = lib.teams.cuda.members;
  };
} ./no-broken-symlinks-hook.sh
