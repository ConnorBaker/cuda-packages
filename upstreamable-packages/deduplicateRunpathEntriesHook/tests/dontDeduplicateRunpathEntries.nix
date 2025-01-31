# NOTE: Tests for dontDeduplicateRunpathEntries option go here.
{
  mkCheckExpectedRunpath,
  ...
}:
{
  # Should deduplicate when dontDeduplicateRunpathEntries is not set.
  flag-unset = mkCheckExpectedRunpath.override {
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
  flag-set-false = mkCheckExpectedRunpath.override (prevAttrs: {
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
    derivationArgs = prevAttrs.derivationArgs or { } // {
      dontDeduplicateRunpathEntries = false;
    };
  });

  # Should not deduplicate when dontDeduplicateRunpathEntries is set to true.
  flag-set-true = mkCheckExpectedRunpath.override (prevAttrs: {
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
    derivationArgs = prevAttrs.derivationArgs or { } // {
      dontDeduplicateRunpathEntries = true;
    };
  });
}
