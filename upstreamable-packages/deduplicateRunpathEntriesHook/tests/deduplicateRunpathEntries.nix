# NOTE: Tests for deduplicateRunpathEntries go here.
{
  mkCheckExpectedRunpath,
  ...
}:
{
  allUnique = mkCheckExpectedRunpath.override {
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

  oneUniqueOneDuplicate = mkCheckExpectedRunpath.override {
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

  allDuplicates = mkCheckExpectedRunpath.override {
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
