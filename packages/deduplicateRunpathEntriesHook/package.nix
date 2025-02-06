{
  arrayUtilitiesHook,
  autoFixElfFiles,
  callPackages,
  lib,
  makeSetupHook,
  patchelf,
}:
makeSetupHook {
  name = "deduplicate-runpath-entries-hook";
  propagatedBuildInputs = [
    # Used in the setup hook
    arrayUtilitiesHook
    # Used in the setup hook
    autoFixElfFiles
    # Use in the setup hook
    patchelf
  ];
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
