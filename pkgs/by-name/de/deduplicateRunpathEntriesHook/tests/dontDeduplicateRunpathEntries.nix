# NOTE: Tests for dontDeduplicateRunpathEntries option go here.
{
  arrayUtilities,
  deduplicateRunpathEntriesHook,
  lib,
  testers,
}:
let
  inherit (arrayUtilities) getRunpathEntries;
  inherit (testers) makeMainWithRunpath testEqualArrayOrMap;

  check =
    {
      name,
      runpathEntries,
      expectedRunpathEntries ? runpathEntries, # default to runpathEntries
    }:
    (testEqualArrayOrMap {
      name = "${deduplicateRunpathEntriesHook.name}-${name}";
      valuesArray = runpathEntries;
      expectedArray = expectedRunpathEntries;
      script = ''
        nixLog "installing main"
        install -Dm677 "${makeMainWithRunpath { inherit runpathEntries; }}/bin/main" main
        nixLog "running deduplicateRunpathEntries on main"
        deduplicateRunpathEntries main
        nixLog "populating actualArray"
        getRunpathEntries main actualArray
      '';
    }).overrideAttrs
      (prevAttrs: {
        nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
          getRunpathEntries
          deduplicateRunpathEntriesHook
        ];
      });
in
lib.recurseIntoAttrs {
  # Should deduplicate when dontDeduplicateRunpathEntries is not set.
  flag-unset = check {
    name = "flag-unset";
    runpathEntries = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
    expectedRunpathEntries = [
      "bee"
      "apple"
      "dog"
      "cat"
    ];
  };

  # Should deduplicate when dontDeduplicateRunpathEntries is set to false.
  flag-set-false =
    (check {
      name = "flag-set-false";
      runpathEntries = [
        "bee"
        "apple"
        "dog"
        "apple"
        "cat"
      ];
      expectedRunpathEntries = [
        "bee"
        "apple"
        "dog"
        "cat"
      ];
    }).overrideAttrs
      { dontDeduplicateRunpathEntries = false; };

  # Should not deduplicate when dontDeduplicateRunpathEntries is set to true.
  flag-set-true =
    (check {
      name = "flag-set-true";
      runpathEntries = [
        "bee"
        "apple"
        "dog"
        "apple"
        "cat"
      ];
    }).overrideAttrs
      { dontDeduplicateRunpathEntries = true; };
}
