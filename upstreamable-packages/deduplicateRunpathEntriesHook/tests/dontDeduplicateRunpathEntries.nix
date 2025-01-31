# NOTE: Tests for dontDeduplicateRunpathEntries option go here.
{
  deduplicateRunpathEntriesHook,
  mkCheckExpectedRunpath,
}:
let
  check = mkCheckExpectedRunpath.overrideAttrs (prevAttrs: {
    nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [ deduplicateRunpathEntriesHook ];
    checkSetupScript = ''
      nixLog "running deduplicateRunpathEntries on main"
      deduplicateRunpathEntries main
    '';
  });
in
{
  # Should deduplicate when dontDeduplicateRunpathEntries is not set.
  flag-unset = check.overrideAttrs {
    name = "flag-unset";
    valuesArr = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
    expectedArr = [
      "bee"
      "apple"
      "dog"
      "cat"
    ];
  };

  # Should deduplicate when dontDeduplicateRunpathEntries is set to false.
  flag-set-false = check.overrideAttrs {
    name = "flag-set-false";
    valuesArr = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
    expectedArr = [
      "bee"
      "apple"
      "dog"
      "cat"
    ];
    dontDeduplicateRunpathEntries = false;
  };

  # Should not deduplicate when dontDeduplicateRunpathEntries is set to true.
  flag-set-true = check.overrideAttrs {
    name = "flag-set-true";
    valuesArr = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
    expectedArr = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
    dontDeduplicateRunpathEntries = true;
  };
}
