{
  callPackages,
  lib,
  makeSetupHook,
}:
makeSetupHook {
  name = "array-utilities-hook";
  passthru.tests = {
    computeFrequencyMap = callPackages ./tests/computeFrequencyMap.nix { };
    deduplicateArray = callPackages ./tests/deduplicateArray.nix { };
    occursOnlyOrBeforeInArray = callPackages ./tests/occursOnlyOrBeforeInArray.nix { };
  };
  meta = {
    description = "Adds common array utilities";
    maintainers = lib.teams.cuda.members;
  };
} ./array-utilities-hook.sh
