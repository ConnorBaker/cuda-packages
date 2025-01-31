{
  arrayUtilitiesHook,
  lib,
  mkCheckExpectedArrayAndMap,
  nixLogWithLevelAndFunctionNameHook,
  stdenv,
  testers,
}:
let
  args = {
    inherit
      arrayUtilitiesHook
      lib
      mkCheckExpectedArrayAndMap
      nixLogWithLevelAndFunctionNameHook
      stdenv
      testers
      ;
  };
in
{
  # Tests for computeFrequencyMap.
  computeFrequencyMap = import ./computeFrequencyMap.nix args;

  # Tests for deduplicateArray.
  deduplicateArray = import ./deduplicateArray.nix args;

  # Tests for occursOnlyOrBeforeInArray.
  occursOnlyOrBeforeInArray = import ./occursOnlyOrBeforeInArray.nix args;

  # TODO: Tests for other functions go here.
}
