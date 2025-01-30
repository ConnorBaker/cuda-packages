# NOTE: Tests related to computeFrequencyMap go here.
{
  arrayUtilitiesHook,
  nixLogWithLevelAndFunctionNameHook,
  runCommand,
  stdenv,
  testers,
  ...
}:
let
  inherit (testers) testBuildFailure;
  mkCheck =
    {
      name,
      valuesArr ? [ ],
      expectedMap ? { },
    }:
    stdenv.mkDerivation {
      inherit name;
      # NOTE: Must set name!
      strictDeps = true;
      __structuredAttrs = true;
      src = null;
      inherit valuesArr expectedMap;
      nativeBuildInputs = [
        nixLogWithLevelAndFunctionNameHook
        arrayUtilitiesHook
      ];
      # TODO: REPLACE WITH SCRIPTS IMPORT
      dontUnpack = true;
      dontBuild = true;
      doCheck = true;
      checkPhase = ''
        runHook preCheck

        nixLog "running with values: $(declare -p valuesArr)"

        local -A actualMap=()
        computeFrequencyMap valuesArr actualMap

        ${builtins.readFile ./assert-map-is-submap.sh}

        nixLog "ensuring expectedMap is a submap of actualMap"
        assertMapIsSubmap expectedMap actualMap

        nixLog "ensuring actualMap is a submap of expectedMap"
        assertMapIsSubmap actualMap expectedMap

        nixLog "the test passed"
        runHook postCheck
      '';
      installPhase = ''
        runHook preInstall
        touch "$out"
        runHook postInstall
      '';
    };
in
{
  test0 = mkCheck {
    name = "test0";
    valuesArr = [ ];
    expectedMap = { };
  };
  test1 = mkCheck {
    name = "test1";
    valuesArr = [ "apple" ];
    expectedMap = {
      apple = 1;
    };
  };
  test2 = mkCheck {
    name = "test2";
    valuesArr = [
      "apple"
      "bee"
    ];
    expectedMap = {
      apple = 1;
      bee = 1;
    };
  };
  test3 = mkCheck {
    name = "test3";
    valuesArr = [
      "apple"
      "apple"
    ];
    expectedMap = {
      apple = 2;
    };
  };
  test4 = mkCheck {
    name = "test4";
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
  test5 =
    runCommand "test5"
      {
        failed = testBuildFailure (mkCheck {
          name = "test5-inner";
          valuesArr = [ ];
          expectedMap = {
            apple = 1;
          };
        });
      }
      ''
        echo "Checking for exit code 1" >&$NIX_LOG_FD
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        echo "Checking for first error message" >&$NIX_LOG_FD
        grep -F \
          "ERROR: assertMapIsSubmap: submap has more keys than supermap: submap has length 1 but supermap has length 0" \
          "$failed/testBuildFailure.log"
        echo "Checking for second error message" >&$NIX_LOG_FD
        grep -F \
          "ERROR: assertMapIsSubmap: submap has key 'apple' with value '1' but supermap has no such key" \
          "$failed/testBuildFailure.log"
        echo "Test passed" >&$NIX_LOG_FD
        touch $out
      '';

  test6 =
    runCommand "test6"
      {
        failed = testBuildFailure (mkCheck {
          name = "test6-inner";
          valuesArr = [
            "apple"
            "bee"
            "apple"
          ];
          expectedMap = {
            apple = 1;
            bee = 1;
          };
        });
      }
      ''
        echo "Checking for exit code 1" >&$NIX_LOG_FD
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        echo "Checking for error message" >&$NIX_LOG_FD
        grep -F \
          "ERROR: assertMapIsSubmap: maps differ at key 'apple': submap value is '1' but supermap value is '2'" \
          "$failed/testBuildFailure.log"
        echo "Test passed" >&$NIX_LOG_FD
        touch $out
      '';

  test7 =
    runCommand "test7"
      {
        failed = testBuildFailure (mkCheck {
          name = "test7-inner";
          valuesArr = [
            "cat"
            "apple"
            "bee"
          ];
          expectedMap = {
            apple = 1;
            bee = 1;
          };
        });
      }
      ''
        echo "Checking for exit code 1" >&$NIX_LOG_FD
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        echo "Checking for first error message" >&$NIX_LOG_FD
        grep -F \
          "ERROR: assertMapIsSubmap: submap has more keys than supermap: submap has length 3 but supermap has length 2" \
          "$failed/testBuildFailure.log"
        echo "Checking for second error message" >&$NIX_LOG_FD
        grep -F \
          "ERROR: assertMapIsSubmap: submap has key 'cat' with value '1' but supermap has no such key" \
          "$failed/testBuildFailure.log"
        echo "Test passed" >&$NIX_LOG_FD
        touch $out
      '';

  test8 =
    runCommand "test8"
      {
        failed = testBuildFailure (mkCheck {
          name = "test8-inner";
          valuesArr = "apple";
        });
      }
      ''
        echo "Checking for exit code 1" >&$NIX_LOG_FD
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        echo "Checking for error message" >&$NIX_LOG_FD
        grep -F \
          "ERROR: computeFrequencyMap: first arugment inputArrRef must be an array reference" \
          "$failed/testBuildFailure.log"
        echo "Test passed" >&$NIX_LOG_FD
        touch $out
      '';

  test9 =
    runCommand "test9"
      {
        failed = testBuildFailure (mkCheck {
          name = "test9-inner";
          valuesArr.apple = 1;
        });
      }
      ''
        echo "Checking for exit code 1" >&$NIX_LOG_FD
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        echo "Checking for error message" >&$NIX_LOG_FD
        grep -F \
          "ERROR: computeFrequencyMap: first arugment inputArrRef must be an array reference" \
          "$failed/testBuildFailure.log"
        echo "Test passed" >&$NIX_LOG_FD
        touch $out
      '';

  test10 =
    runCommand "test10"
      {
        failed = testBuildFailure (
          (mkCheck {
            name = "test10-inner";
          }).overrideAttrs
            {
              checkPhase = ''
                local -a actualMap=()
                computeFrequencyMap valuesArr actualMap
              '';
            }
        );
      }
      ''
        echo "Checking for exit code 1" >&$NIX_LOG_FD
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        echo "Checking for error message" >&$NIX_LOG_FD
        grep -F \
          "ERROR: computeFrequencyMap: second arugment outputMapRef must be an associative array reference" \
          "$failed/testBuildFailure.log"
        echo "Test passed" >&$NIX_LOG_FD
        touch $out
      '';

  test11 =
    runCommand "test11"
      {
        failed = testBuildFailure (
          (mkCheck {
            name = "test10-inner";
          }).overrideAttrs
            {
              checkPhase = ''
                local actualMap="hello!"
                computeFrequencyMap valuesArr actualMap
              '';
            }
        );
      }
      ''
        echo "Checking for exit code 1" >&$NIX_LOG_FD
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        echo "Checking for error message" >&$NIX_LOG_FD
        grep -F \
          "ERROR: computeFrequencyMap: second arugment outputMapRef must be an associative array reference" \
          "$failed/testBuildFailure.log"
        echo "Test passed" >&$NIX_LOG_FD
        touch $out
      '';
}
