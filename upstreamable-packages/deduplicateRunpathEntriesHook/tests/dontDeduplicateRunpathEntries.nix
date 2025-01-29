# NOTE: Tests for dontDeduplicateRunpathEntries option go here.
{
  cc-lib-dir,
  mkCApplicationWithRunpathEntries,
  ...
}:
{
  # TODO: How can I get the output of the log to ensure the error message is printed?
  # Default behavior is to dedpulicate.
  flag-unset = mkCApplicationWithRunpathEntries {
    name = "flag-unset";
    runpathEntries = [ cc-lib-dir ];
    dontDeduplicateRunpathEntries = null;
    postHookCheck = ''
      nixLog "Checking that the default of dontDeduplicateRunpathEntries is to deduplicate"
      test "''${POST_HOOK_RPATH:?}" = "''${ORIGINAL_RPATH:?}"
    '';
  };

  flag-set-false = mkCApplicationWithRunpathEntries {
    name = "flag-set-false";
    runpathEntries = [ cc-lib-dir ];
    dontDeduplicateRunpathEntries = false;
    postHookCheck = ''
      nixLog "Checking that dontDeduplicateRunpathEntries deduplicates when set to false"
      test "''${POST_HOOK_RPATH:?}" != "''${ORIGINAL_RPATH:?}"
    '';
  };

  flag-set-true = mkCApplicationWithRunpathEntries {
    name = "flag-set-true";
    runpathEntries = [ cc-lib-dir ];
    dontDeduplicateRunpathEntries = true;
    postHookCheck = ''
      nixLog "Checking that dontDeduplicateRunpathEntries disables deduplication when set to true"
      test "''${POST_HOOK_RPATH:?}" != "''${ORIGINAL_RPATH:?}"
    '';
  };
}
