# NOTE: Tests for dontDeduplicateRunpathEntries option go here.
{
  deduplicateRunpathEntriesHook,
  mkCheckExpectedRunpath,
}:
let
  check = mkCheckExpectedRunpath.overrideAttrs (prevAttrs: {
    nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [ deduplicateRunpathEntriesHook ];
    script = ''
      nixLog "running deduplicateRunpathEntries on main"
      deduplicateRunpathEntries main
    '';
  });
in
{
  # Should deduplicate when dontDeduplicateRunpathEntries is not set.
  flag-unset = check.overrideAttrs {
    name = "flag-unset";
    valuesArray = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
    expectedArray = [
      "bee"
      "apple"
      "dog"
      "cat"
    ];
  };

  # Should deduplicate when dontDeduplicateRunpathEntries is set to false.
  flag-set-false = check.overrideAttrs {
    name = "flag-set-false";
    valuesArray = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
    expectedArray = [
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
    valuesArray = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
    expectedArray = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
    dontDeduplicateRunpathEntries = true;
  };
}
