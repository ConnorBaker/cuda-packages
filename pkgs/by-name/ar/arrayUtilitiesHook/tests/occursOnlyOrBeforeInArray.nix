# NOTE: Tests related to occursOnlyOrBeforeInArray go here.
{
  arrayUtilitiesHook,
  testers,
}:
let
  inherit (testers) runCommand;

  check =
    {
      name,
      value1,
      value2,
      valuesArr,
      shouldPass,
    }:
    runCommand {
      inherit
        name
        value1
        value2
        valuesArr
        shouldPass
        ;
      strictDeps = true;
      __structuredAttrs = true;
      nativeBuildInputs = [
        arrayUtilitiesHook
      ];
      script = ''
        nixLog "using value1: '$value1'"
        nixLog "using value2: '$value2'"
        nixLog "using valuesArr: $(declare -p valuesArr)"
        nixLog "using shouldPass: $((shouldPass))"
        nixLog "running occursOnlyOrBeforeInArray with value1 value2 valuesArr"

        if occursOnlyOrBeforeInArray "$value1" "$value2" valuesArr; then
          if ((shouldPass)); then
            nixLog "Test passed as expected"
            touch $out
          else
            nixErrorLog "Test passed but should have failed!"
            exit 1
          fi
        else
          if ((shouldPass)); then
            nixErrorLog "Test failed but should have passed!"
            exit 1
          else
            nixLog "Test failed as expected"
            touch $out
          fi
        fi
      '';
    };
in
{
  emptyArray = check {
    name = "emptyArray";
    value1 = "apple";
    value2 = "bee";
    valuesArr = [ ];
    shouldPass = false;
  };
  emptyStringForValue1 = check {
    name = "emptyString";
    value1 = "";
    value2 = "bee";
    valuesArr = [ "" ];
    shouldPass = true;
  };
  singleton = check {
    name = "singleton";
    value1 = "apple";
    value2 = "bee";
    valuesArr = [ "apple" ];
    shouldPass = true;
  };
  occursBefore = check {
    name = "occursBefore";
    value1 = "apple";
    value2 = "bee";
    valuesArr = [
      "apple"
      "bee"
    ];
    shouldPass = true;
  };
  occursOnly = check {
    name = "occursOnly";
    value1 = "apple";
    value2 = "bee";
    valuesArr = [ "apple" ];
    shouldPass = true;
  };
  occursAfter = check {
    name = "occursAfter";
    value1 = "apple";
    value2 = "bee";
    valuesArr = [
      "bee"
      "apple"
    ];
    shouldPass = false;
  };
  occursBeforeAlmostAtEnd = check {
    name = "occursBeforeAlmostAtEnd";
    value1 = "apple";
    value2 = "cat";
    valuesArr = [
      "bee"
      "apple"
      "cat"
    ];
    shouldPass = true;
  };
  value1DoesntMatchStringWithPrefix = check {
    name = "value1DoesntMatchStringWithPrefix";
    value1 = "apple";
    value2 = "bee";
    valuesArr = [
      "apple with spaces"
      "bee"
    ];
    shouldPass = false;
  };
  value1DoesntMatchStringWithSuffix = check {
    name = "value1DoesntMatchStringWithSuffix";
    value1 = "apple";
    value2 = "bee";
    valuesArr = [
      "apple in a tree"
      "bee"
    ];
    shouldPass = false;
  };
  value2DoesntMatchStringWithPrefix = check {
    name = "value2DoesntMatchStringWithPrefix";
    value1 = "apple";
    value2 = "bee";
    valuesArr = [
      "bee with spaces"
      "apple"
    ];
    shouldPass = true;
  };
  value2DoesntMatchStringWithSuffix = check {
    name = "value2DoesntMatchStringWithSuffix";
    value1 = "apple";
    value2 = "bee";
    valuesArr = [
      "bee in a tree"
      "apple"
    ];
    shouldPass = true;
  };
  value1HasLineBreakOccursBefore = check {
    name = "value1HasLineBreakOccursBefore";
    value1 = ''
      apple

      up

      high
    '';
    value2 = "bee";
    valuesArr = [
      "cat"
      ''
        apple

        up

        high
      ''
      ''line break ''
      "bee"
    ];
    shouldPass = true;
  };
  value1HasLineBreakOccursAfter = check {
    name = "value1HasLineBreakOccursAfter";
    value1 = ''
      apple

      up

      high
    '';
    value2 = "bee";
    valuesArr = [
      "cat"
      "bee"
      ''
        apple

        up

        high
      ''
      ''line break ''
    ];
    shouldPass = false;
  };
}
