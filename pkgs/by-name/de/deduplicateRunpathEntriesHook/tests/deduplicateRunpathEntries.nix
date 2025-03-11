# NOTE: Tests for deduplicateRunpathEntries go here.
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
  allUnique = check {
    name = "allUnique";
    runpathEntries = [
      "bee"
      "frog"
      "apple"
      "dog"
    ];
  };

  oneUniqueOneDuplicate = check {
    name = "oneUniqueOneDuplicate";
    runpathEntries = [
      "apple"
      "bee"
      "apple"
    ];
    expectedRunpathEntries = [
      "apple"
      "bee"
    ];
  };

  allDuplicates = check {
    name = "duplicate-rpath-entries";
    runpathEntries = [
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
    expectedRunpathEntries = [
      "apple"
      "bee"
      "dog"
      "cat"
      "frog"
    ];
  };
}
