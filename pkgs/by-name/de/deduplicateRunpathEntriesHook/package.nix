{
  arrayUtilities,
  autoFixElfFiles,
  callPackages,
  lib,
  makeSetupHook',
  patchelf,
}:
# TODO(@connorbaker): This functionality should be subsumed by runpathFixup.
makeSetupHook' {
  name = "deduplicateRunpathEntriesHook";
  nativeBuildInputs = [
    # Used in the setup hook
    arrayUtilities.getRunpathEntries
    arrayUtilities.occursOnlyOrAfterInArray
    arrayUtilities.deduplicateArray
    # Used in the setup hook
    autoFixElfFiles
    # Use in the setup hook
    patchelf
  ];
  script = ./deduplicateRunpathEntriesHook.bash;
  passthru.tests = lib.recurseIntoAttrs {
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
}
