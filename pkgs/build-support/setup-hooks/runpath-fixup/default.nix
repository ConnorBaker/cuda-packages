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
  name = "runpath-fixup";
  passthru.tests = recurseIntoAttrs {
    # computeFrequencyMap = callPackages ./tests/computeFrequencyMap.nix { };
    # deduplicateArray = callPackages ./tests/deduplicateArray.nix { };
    # occursOnlyOrBeforeInArray = callPackages ./tests/occursOnlyOrBeforeInArray.nix { };
  };
  meta = {
    description = "Perform runpath fixups";
    maintainers = cuda.members;
  };
} ./runpath-fixup.sh
