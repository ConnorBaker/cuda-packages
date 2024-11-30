{
  lib,
  makeSetupHook,
  nixLogWithLevelAndFunctionNameHook,
}:
makeSetupHook {
  name = "no-broken-symlinks-hook";
  propagatedBuildInputs = [
    # We add a hook to replace the standard logging functions.
    nixLogWithLevelAndFunctionNameHook
  ];
  substitutions.nixLogWithLevelAndFunctionNameHook = "${nixLogWithLevelAndFunctionNameHook}/nix-support/setup-hook";
  meta = {
    description = "Checks for broken symlinks within outputs";
    maintainers = lib.teams.cuda.members;
  };
} ./no-broken-symlinks-hook.sh
