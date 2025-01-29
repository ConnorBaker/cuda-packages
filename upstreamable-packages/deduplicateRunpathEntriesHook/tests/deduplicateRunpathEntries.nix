# NOTE: Tests for deduplicateRunpathEntries go here.
{
  cc-lib-dir,
  cc-libc-lib-dir,
  mkCApplicationWithRunpathEntries,
  ...
}:
{
  no-duplicate-rpath-entries = mkCApplicationWithRunpathEntries {
    name = "no-duplicate-rpath-entries";
    runpathEntries = [ ];
    postHookCheck = ''
      nixLog "Checking that the runpath is unchanged when there are no duplicates"
      test "''${POST_HOOK_RPATH:?}" = "''${ORIGINAL_RPATH:?}"
    '';
  };

  duplicate-rpath-entry = mkCApplicationWithRunpathEntries {
    name = "duplicate-rpath-entry";
    runpathEntries = [ cc-lib-dir ];
    postHookCheck = ''
      nixLog "Checking that the hook removed the duplicate runpath entry"
      test "''${POST_HOOK_RPATH:?}" = "''${ORIGINAL_RPATH:?}"
    '';
  };

  duplicate-rpath-entries = mkCApplicationWithRunpathEntries {
    name = "duplicate-rpath-entries";
    runpathEntries = [
      cc-lib-dir
      cc-libc-lib-dir
    ];
    postHookCheck = ''
      nixLog "Checking that the hook removed the duplicate runpath entries"
      test "''${POST_HOOK_RPATH:?}" = "''${ORIGINAL_RPATH:?}"
    '';
  };
}
