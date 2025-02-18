# NOTE: Tests related to deduplicateArray go here.
{
  arrayUtilitiesHook,
  mkCheckExpectedArrayAndMap,
  testers,
}:
let
  inherit (testers) runCommand testBuildFailure;
  check = mkCheckExpectedArrayAndMap.overrideAttrs (prevAttrs: {
    nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [ arrayUtilitiesHook ];
    checkSetupScript = ''
      nixLog "running deduplicateArray with valuesArr to populate actualArr"
      deduplicateArray valuesArr actualArr
    '';
  });
in
{
  empty = check.overrideAttrs {
    name = "empty";
    valuesArr = [ ];
    expectedArr = [ ];
  };
  singleton = check.overrideAttrs {
    name = "singleton";
    valuesArr = [ "apple" ];
    expectedArr = [ "apple" ];
  };
  allUniqueOrderPreserved = check.overrideAttrs {
    name = "allUniqueOrderPreserved";
    valuesArr = [
      "apple"
      "bee"
    ];
    expectedArr = [
      "apple"
      "bee"
    ];
  };
  oneDuplicate = check.overrideAttrs {
    name = "oneDuplicate";
    valuesArr = [
      "apple"
      "apple"
    ];
    expectedArr = [
      "apple"
    ];
  };
  oneUniqueOrderPreserved = check.overrideAttrs {
    name = "oneUniqueOrderPreserved";
    valuesArr = [
      "bee"
      "apple"
      "bee"
    ];
    expectedArr = [
      "bee"
      "apple"
    ];
  };
  duplicatesWithSpacesAndLineBreaks = check.overrideAttrs {
    name = "duplicatesWithSpacesAndLineBreaks";
    valuesArr = [
      "dog"
      "bee"
      ''
        line
        break
      ''
      "cat"
      "zebra"
      "bee"
      "cat"
      "elephant"
      "dog with spaces"
      ''
        line
        break
      ''
    ];
    expectedArr = [
      "dog"
      "bee"
      ''
        line
        break
      ''
      "cat"
      "zebra"
      "elephant"
      "dog with spaces"
    ];
  };
  failNoDeduplication = runCommand {
    name = "failNoDeduplication";
    failed = testBuildFailure (
      check.overrideAttrs {
        name = "failNoDeduplicationInner";
        valuesArr = [
          "bee"
          "apple"
          "bee"
        ];
        expectedArr = [
          "bee"
          "apple"
          "bee"
        ];
      }
    );
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for first error message"
      grep -F \
        "ERROR: assertArraysAreEqual: arrays differ in length: expectedArrayRef has length 3 but actualArrayRef has length 2" \
        "$failed/testBuildFailure.log"
      nixLog "Checking for second error message"
      grep -F \
        "ERROR: assertArraysAreEqual: arrays differ at index 2: expected value is 'bee' but actual value would be out of bounds" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

}
