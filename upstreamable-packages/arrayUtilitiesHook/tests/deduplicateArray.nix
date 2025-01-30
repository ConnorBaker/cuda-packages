# NOTE: Tests related to deduplicateArray go here.
{
  arrayUtilitiesHook,
  lib,
  nixLogWithLevelAndFunctionNameHook,
  runCommand,
  stdenv,
  testers,
  ...
}:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.strings) optionalString;
  inherit (testers) testBuildFailure;

  mkCheck =
    {
      name,
      valuesArr ? [ ],
      expectedArr ? [ ],
      expectedMap ? null,
    }:
    stdenv.mkDerivation (
      {
        inherit name;
        # NOTE: Must set name!
        strictDeps = true;
        __structuredAttrs = true;
        src = null;
        inherit valuesArr expectedArr;
        nativeBuildInputs = [
          nixLogWithLevelAndFunctionNameHook
          arrayUtilitiesHook
        ];
        dontUnpack = true;
        dontBuild = true;
        doCheck = true;
        checkPhase =
          ''
            runHook preCheck

            nixLog "running with values: $(declare -p valuesArr)"
            local -a actualArr=()

            ${optionalString (expectedMap != null) "local -A actualMap=()"}
            deduplicateArray valuesArr actualArr ${optionalString (expectedMap != null) "actualMap"}

            nixLog "expectedArr: $(declare -p expectedArr)"
            nixLog "actualArr: $(declare -p actualArr)"
            ${optionalString (expectedMap != null) ''
              nixLog "expectedMap: $(declare -p expectedMap)"
              nixLog "actualMap: $(declare -p actualMap)"
            ''}

            ${builtins.readFile ./assert-arrays-are-equal.sh}

            nixLog "ensuring expectedArr equals actualArr"
            assertArraysAreEqual expectedArr actualArr
          ''
          + optionalString (expectedMap != null) ''
            ${builtins.readFile ./assert-map-is-submap.sh}

            nixLog "ensuring expectedMap is a submap of actualMap"
            assertMapIsSubmap expectedMap actualMap

            nixLog "ensuring actualMap is a submap of expectedMap"
            assertMapIsSubmap actualMap expectedMap
            runHook postCheck
          '';
        installPhase = ''
          runHook preInstall
          touch "$out"
          runHook postInstall
        '';
      }
      // optionalAttrs (expectedMap != null) { inherit expectedMap; }
    );
in
{
  test0 = mkCheck {
    name = "test0";
    valuesArr = [ ];
    expectedArr = [ ];
  };
  test1 = mkCheck {
    name = "test1";
    valuesArr = [ "apple" ];
    expectedArr = [ "apple" ];
  };
  test2 = mkCheck {
    name = "test2";
    valuesArr = [
      "apple"
      "bee"
    ];
    expectedArr = [
      "apple"
      "bee"
    ];
  };
  test3 = mkCheck {
    name = "test3";
    valuesArr = [
      "apple"
      "apple"
    ];
    expectedArr = [
      "apple"
    ];
  };
  test4 = mkCheck {
    name = "test4";
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
  test5 =
    runCommand "test5"
      {
        failed = testBuildFailure (mkCheck {
          name = "test5-inner";
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
        });
      }
      ''
        echo "Checking for exit code 1" >&$NIX_LOG_FD
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        echo "Checking for first error message" >&$NIX_LOG_FD
        grep -F \
          "ERROR: assertArraysAreEqual: Arrays differ in length: expectedArrayRef has length 3 but actualArrayRef has length 2" \
          "$failed/testBuildFailure.log"
        echo "Checking for second error message" >&$NIX_LOG_FD
        grep -F \
          "ERROR: assertArraysAreEqual: Arrays differ at index 2: expected value is 'bee' but actual value would be out of bounds" \
          "$failed/testBuildFailure.log"
        echo "Test passed" >&$NIX_LOG_FD
        touch $out
      '';
  test6 = mkCheck {
    name = "test6";
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
}
