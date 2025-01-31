{
  arrayUtilitiesHook,
  autoFixElfFiles,
  lib,
  makeSetupHook,
  nixLogWithLevelAndFunctionNameHook,
  patchelf,

  # passthru.tests
  autoPatchelfHook,
  deduplicateRunpathEntriesHook,
  mkCheckExpectedArrayAndMap,
  stdenv,
  testers,
}:
makeSetupHook {
  name = "deduplicate-runpath-entries-hook";
  propagatedBuildInputs = [
    # Used in the setup hook
    arrayUtilitiesHook
    # Used in the setup hook
    autoFixElfFiles
    # We add a hook to replace the standard logging functions.
    nixLogWithLevelAndFunctionNameHook
    # Use in the setup hook
    patchelf
  ];
  substitutions.nixLogWithLevelAndFunctionNameHook = "${nixLogWithLevelAndFunctionNameHook}/nix-support/setup-hook";
  passthru.tests = import ./tests {
    inherit
      autoPatchelfHook
      deduplicateRunpathEntriesHook
      mkCheckExpectedArrayAndMap
      nixLogWithLevelAndFunctionNameHook
      patchelf
      stdenv
      testers
      ;
  };
  meta = {
    description = "Checks for and optionally removes duplicate runpath entries within outputs";
    maintainers = lib.teams.cuda.members;
  };
} ./deduplicate-runpath-entries-hook.sh
