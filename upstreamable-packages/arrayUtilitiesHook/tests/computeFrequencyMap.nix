# NOTE: Tests related to computeFrequencyMap go here.
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
      nixLog "running computeFrequencyMap with valuesArr to populate actualMap"
      computeFrequencyMap valuesArr actualMap
    '';
    extraNativeBuildInputs = [ arrayUtilitiesHook ];
  };
in
{
  empty = check.override {
    name = "empty";
    valuesArr = [ ];
    expectedMap = { };
  };
  singleton = check.override {
    name = "singleton";
    valuesArr = [ "apple" ];
    expectedMap.apple = 1;
  };
  twoUnique = check.override {
    name = "twoUnique";
    valuesArr = [
      "apple"
      "bee"
    ];
    expectedMap = {
      apple = 1;
      bee = 1;
    };
  };
  oneDuplicate = check.override {
    name = "oneDuplicate";
    valuesArr = [
      "apple"
      "apple"
    ];
    expectedMap.apple = 2;
  };
  oneUniqueOneDuplicate = check.override {
    name = "oneUniqueOneDuplicate";
    valuesArr = [
      "bee"
      "apple"
      "bee"
    ];
    expectedMap = {
      apple = 1;
      bee = 2;
    };
  };
  failMissingKeyWithEmpty = runCommand {
    name = "failMissingKeyWithEmpty";
    nativeBuildInputs = [ nixLogWithLevelAndFunctionNameHook ];
    failed = testBuildFailure (
      check.override {
        name = "failMissingKeyWithEmptyInner";
        valuesArr = [ ];
        expectedMap.apple = 1;
      }
    );
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for first error message"
      grep -F \
        "ERROR: assertMapsAreEqual: maps differ in number of keys: expectedMap has length 1 but actualMap has length 0" \
        "$failed/testBuildFailure.log"
      nixLog "Checking for second error message"
      grep -F \
        "ERROR: assertMapsAreEqual: expectedMap has key 'apple' with value '1' but actualMap has no such key" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  failIncorrectFrequency = runCommand {
    name = "failIncorrectFrequency";
    nativeBuildInputs = [ nixLogWithLevelAndFunctionNameHook ];
    failed = testBuildFailure (
      check.override {
        name = "failIncorrectFrequencyInner";
        valuesArr = [
          "apple"
          "bee"
          "apple"
        ];
        expectedMap = {
          apple = 1;
          bee = 1;
        };
      }
    );
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for error message"
      grep -F \
        "ERROR: assertMapsAreEqual: maps differ at key 'apple': expectedMap value is '1' but actualMap value is '2'" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  failMissingKeyWithNonEmpty = runCommand {
    name = "failMissingKeyWithNonEmpty";
    nativeBuildInputs = [ nixLogWithLevelAndFunctionNameHook ];
    failed = testBuildFailure (
      check.override {
        name = "failMissingKeyWithNonEmptyInner";
        valuesArr = [
          "cat"
          "apple"
          "bee"
        ];
        expectedMap = {
          apple = 1;
          bee = 1;
        };
      }
    );
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for first error message"
      grep -F \
        "ERROR: assertMapsAreEqual: maps differ in number of keys: expectedMap has length 2 but actualMap has length 3" \
        "$failed/testBuildFailure.log"
      nixLog "Checking for second error message"
      grep -F \
        "ERROR: assertMapsAreEqual: actualMap has key 'cat' with value '1' but expectedMap has no such key" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  failFirstArgumentIsString = runCommand {
    name = "failFirstArgumentIsString";
    nativeBuildInputs = [ nixLogWithLevelAndFunctionNameHook ];
    failed = testBuildFailure (
      check.override {
        name = "failFirstArgumentIsStringInner";
        valuesArr = "apple";
        expectedMap = { };
      }
    );
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for error message"
      grep -F \
        "ERROR: computeFrequencyMap: first arugment inputArrRef must be an array reference" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  failFirstArgumentIsMap = runCommand {
    name = "failFirstArgumentIsMap";
    nativeBuildInputs = [ nixLogWithLevelAndFunctionNameHook ];
    failed = testBuildFailure (
      check.override {
        name = "failFirstArgumentIsMapInner";
        valuesArr.apple = 1;
        expectedMap = { };
      }
    );
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for error message"
      grep -F \
        "ERROR: computeFrequencyMap: first arugment inputArrRef must be an array reference" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  failSecondArgumentIsArray = runCommand {
    name = "failSecondArgumentIsArray";
    nativeBuildInputs = [ nixLogWithLevelAndFunctionNameHook ];
    failed = testBuildFailure (
      check.override (prevAttrs: {
        name = "failSecondArgumentIsArrayInner";
        valuesArr = [ ];
        expectedMap = { };
        setup =
          ''
            nixLog "unsetting and re-declaring actualMap to be an array"
            unset actualMap
            local -a actualMap=()
          ''
          + prevAttrs.setup;
      })
    );
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for error message"
      grep -F \
        "ERROR: computeFrequencyMap: second arugment outputMapRef must be an associative array reference" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  failSecondArgumentIsString = runCommand {
    name = "failSecondArgumentIsString";
    nativeBuildInputs = [ nixLogWithLevelAndFunctionNameHook ];
    failed = testBuildFailure (
      check.override (prevAttrs: {
        name = "failSecondArgumentIsStringInner";
        valuesArr = [ ];
        expectedMap = { };
        setup =
          ''
            nixLog "unsetting and re-declaring actualMap to be a string"
            unset actualMap
            local actualMap="hello!"
          ''
          + prevAttrs.setup;
      })
    );
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for error message"
      grep -F \
        "ERROR: computeFrequencyMap: second arugment outputMapRef must be an associative array reference" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };
}
