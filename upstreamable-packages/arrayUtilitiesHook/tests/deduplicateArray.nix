# NOTE: Tests related to deduplicateArray go here.
{
  arrayUtilitiesHook,
  mkCheckExpectedArrayAndMap,
  nixLogWithLevelAndFunctionNameHook,
  testers,
  ...
}:
let
  inherit (testers) runCommand testBuildFailure;
  check = mkCheckExpectedArrayAndMap.override {
    setup = ''
      nixLog "running deduplicateArray with valuesArr to populate actualArr"
      deduplicateArray valuesArr actualArr
    '';
    extraNativeBuildInputs = [ arrayUtilitiesHook ];
  };
in
{
  empty = check.override {
    name = "empty";
    valuesArr = [ ];
    expectedArr = [ ];
  };
  singleton = check.override {
    name = "singleton";
    valuesArr = [ "apple" ];
    expectedArr = [ "apple" ];
  };
  allUniqueOrderPreserved = check.override {
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
  oneDuplicate = check.override {
    name = "oneDuplicate";
    valuesArr = [
      "apple"
      "apple"
    ];
    expectedArr = [
      "apple"
    ];
  };
  oneUniqueOrderPreserved = check.override {
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
  duplicatesWithSpacesAndLineBreaks = check.override {
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
    nativeBuildInputs = [ nixLogWithLevelAndFunctionNameHook ];
    failed = testBuildFailure (
      check.override {
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
