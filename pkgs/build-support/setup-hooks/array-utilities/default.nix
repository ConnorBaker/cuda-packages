{
  callPackages,
  lib,
  makeSetupHook,
}:
let
  inherit (lib.attrsets) recurseIntoAttrs;
  inherit (lib.teams) cuda;
in
makeSetupHook {
  name = "array-utilities";
  passthru.tests = recurseIntoAttrs {
    computeFrequencyMap = callPackages ./tests/computeFrequencyMap.nix { };
    deduplicateArray = callPackages ./tests/deduplicateArray.nix { };
    occursOnlyOrBeforeInArray = callPackages ./tests/occursOnlyOrBeforeInArray.nix { };
  };
  meta = {
    description = "Adds common array utilities";
    maintainers = cuda.members;
  };
} ./array-utilities.sh
