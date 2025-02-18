# NOTE: Tests for deduplicateRunpathEntries go here.
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
  allUnique = check.overrideAttrs {
    name = "allUnique";
    valuesArr = [
      "bee"
      "frog"
      "apple"
      "dog"
    ];
    expectedArr = [
      "bee"
      "frog"
      "apple"
      "dog"
    ];
  };

  oneUniqueOneDuplicate = check.overrideAttrs {
    name = "oneUniqueOneDuplicate";
    valuesArr = [
      "apple"
      "bee"
      "apple"
    ];
    expectedArr = [
      "apple"
      "bee"
    ];
  };

  allDuplicates = check.overrideAttrs {
    name = "duplicate-rpath-entries";
    valuesArr = [
      "apple"
      "apple"
      "bee"
      "dog"
      "apple"
      "cat"
      "frog"
      "apple"
      "dog"
      "frog"
      "apple"
      "cat"
    ];
    expectedArr = [
      "apple"
      "bee"
      "dog"
      "cat"
      "frog"
    ];
  };
}
