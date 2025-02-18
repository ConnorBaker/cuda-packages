# NOTE: Tests related to computeFrequencyMap go here.
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
      nixLog "running computeFrequencyMap with valuesArr to populate actualMap"
      computeFrequencyMap valuesArr actualMap
    '';
  });
in
{
  empty = check.overrideAttrs {
    name = "empty";
    valuesArr = [ ];
    expectedMap = { };
  };
  singleton = check.overrideAttrs {
    name = "singleton";
    valuesArr = [ "apple" ];
    expectedMap.apple = 1;
  };
  twoUnique = check.overrideAttrs {
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
  oneDuplicate = check.overrideAttrs {
    name = "oneDuplicate";
    valuesArr = [
      "apple"
      "apple"
    ];
    expectedMap.apple = 2;
  };
  oneUniqueOneDuplicate = check.overrideAttrs {
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
    failed = testBuildFailure (
      check.overrideAttrs {
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
    failed = testBuildFailure (
      check.overrideAttrs {
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
    failed = testBuildFailure (
      check.overrideAttrs {
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
    failed = testBuildFailure (
      check.overrideAttrs {
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
    failed = testBuildFailure (
      check.overrideAttrs {
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
    failed = testBuildFailure (
      check.overrideAttrs (prevAttrs: {
        name = "failSecondArgumentIsArrayInner";
        valuesArr = [ ];
        expectedMap = { };
        checkSetupScript =
          ''
            nixLog "unsetting and re-declaring actualMap to be an array"
            unset actualMap
            declare -ag actualMap=()
          ''
          + prevAttrs.checkSetupScript;
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
    failed = testBuildFailure (
      check.overrideAttrs (prevAttrs: {
        name = "failSecondArgumentIsStringInner";
        valuesArr = [ ];
        expectedMap = { };
        checkSetupScript =
          ''
            nixLog "unsetting and re-declaring actualMap to be a string"
            unset actualMap
            declare -g actualMap="hello!"
          ''
          + prevAttrs.checkSetupScript;
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
