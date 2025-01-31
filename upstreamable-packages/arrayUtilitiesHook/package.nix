{
  lib,
  makeSetupHook,

  # passthru.tests
  arrayUtilitiesHook,
  mkCheckExpectedArrayAndMap,
  nixLogWithLevelAndFunctionNameHook,
  stdenv,
  testers,
}:
makeSetupHook {
  name = "array-utilities-hook";
  passthru.tests = import ./tests {
    inherit
      arrayUtilitiesHook
      lib
      mkCheckExpectedArrayAndMap
      nixLogWithLevelAndFunctionNameHook
      stdenv
      testers
      ;
  };
  meta = {
    description = "Adds common array utilities";
    maintainers = lib.teams.cuda.members;
  };
} ./array-utilities-hook.sh
