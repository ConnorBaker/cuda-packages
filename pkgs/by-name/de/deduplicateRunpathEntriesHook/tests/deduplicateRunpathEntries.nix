# NOTE: Tests for deduplicateRunpathEntries go here.
{
  deduplicateRunpathEntriesHook,
  testers,
}:
let
  check =
    args:
    (testers.testEqualArrayOrMap args).overrideAttrs (prevAttrs: {
      nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [ deduplicateRunpathEntriesHook ];
      checkSetupScript =
        # Should not pass checkSetupScript because we use our own.
        assert !(args ? checkSetupScript);
        ''
          nixLog "running deduplicateRunpathEntries on main"
          deduplicateRunpathEntries main
        '';
    });
in
{
  allUnique = check {
    name = "allUnique";
    valuesArray = [
      "bee"
      "frog"
      "apple"
      "dog"
    ];
    expectedArray = [
      "bee"
      "frog"
      "apple"
      "dog"
    ];
  };

  oneUniqueOneDuplicate = check {
    name = "oneUniqueOneDuplicate";
    valuesArray = [
      "apple"
      "bee"
      "apple"
    ];
    expectedArray = [
      "apple"
      "bee"
    ];
  };

  allDuplicates = check {
    name = "duplicate-rpath-entries";
    valuesArray = [
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
    expectedArray = [
      "apple"
      "bee"
      "dog"
      "cat"
      "frog"
    ];
  };
}
