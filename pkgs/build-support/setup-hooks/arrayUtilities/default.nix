{
  lib,
  newScope,
  pkgs,
}:
let
  inherit (lib.attrsets) genAttrs recurseIntoAttrs;
  inherit (lib.customisation) callPackagesWith makeScope;
in
makeScope newScope (
  final:
  let
    functions = genAttrs [
      "arrayDifference"
      "arrayReplace"
      "arraysAreEqual"
      "computeFrequencyMap"
      "deduplicateArray"
      "getMapKeys"
      "isDeclaredArray"
      "isDeclaredMap"
      "mapIsSubmap"
      "mapsAreEqual"
      "occursInArray"
      "occursInMapKeys"
      "occursOnlyOrAfterInArray"
      "occursOnlyOrBeforeInArray"
      "sortArray"
    ] (name: final.callPackage (./. + "/${name}") { });
  in
  recurseIntoAttrs {
    # Utility function
    functionGuard = functionName: ''
      # Only run the hook from nativeBuildInputs
      # shellcheck disable=SC2154
      if ((hostOffset == -1 && targetOffset == 0)); then
        nixInfoLog "sourcing ${functionName}.sh"
      else
        return 0
      fi

      if ((''${${functionName}Declared:-0})); then
        nixInfoLog "skipping because ${functionName} has already been declared"
        return 0
      fi

      declare -ig ${functionName}Declared=1
    '';
    callPackages = callPackagesWith (pkgs // final);
  }
  // functions
)
