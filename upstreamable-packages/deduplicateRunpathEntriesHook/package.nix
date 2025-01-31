{
  arrayUtilitiesHook,
  autoFixElfFiles,
  callPackages,
  lib,
  makeSetupHook,
  nixLogWithLevelAndFunctionNameHook,
  patchelf,
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
  passthru.tests = {
    deduplicateRunpathEntries = callPackages ./tests/deduplicateRunpathEntries.nix { };
    deduplicateRunpathEntriesHookOrderCheckPhase =
      callPackages ./tests/deduplicateRunpathEntriesHookOrderCheckPhase.nix
        { };
    dontDeduplicateRunpathEntries = callPackages ./tests/dontDeduplicateRunpathEntries.nix { };
  };
  meta = {
    description = "Checks for and optionally removes duplicate runpath entries within outputs";
    maintainers = lib.teams.cuda.members;
  };
} ./deduplicate-runpath-entries-hook.sh
