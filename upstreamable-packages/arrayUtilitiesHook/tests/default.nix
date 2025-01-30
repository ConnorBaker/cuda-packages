{
  arrayUtilitiesHook,
  lib,
  nixLogWithLevelAndFunctionNameHook,
  runCommand,
  stdenv,
  testers,
}:
let
  args = {
    inherit
      arrayUtilitiesHook
      lib
      nixLogWithLevelAndFunctionNameHook
      runCommand
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

  # TODO: Tests for other functions go here.
}
