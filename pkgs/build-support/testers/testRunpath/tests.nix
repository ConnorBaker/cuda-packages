# NOTE: We must use `pkgs.runCommand` instead of `testers.runCommand` for negative tests -- those wrapped with
# `testers.testBuildFailure`. This is due to the fact that `testers.testBuildFailure` modifies the derivation such that
# it produces an output containing the exit code, logs, and other things. Since `testers.runCommand` expects the empty
# derivation, it produces a hash mismatch.
{
  patchelf,
  runCommand,
  runCommandCC,
  testers,
  ...
}:
let
  inherit (testers) testBuildFailure' testRunpath;
  main =
    runCommandCC "build-main"
      {
        __structuredAttrs = true;
        strictDeps = true;
        nativeBuildInputs = [ patchelf ];
      }
      ''
        set -eu
        nixLog "Creating a small C application, main"
        echo "int main() { return 0; }" > main.c
        cc main.c -o main
        nixLog "Installing main to $out/bin"
        install -Dm755 main "$out/bin/main"
      '';

  mainWithRunpath =
    runpathEntries:
    runCommand "build-main-with-runpath"
      {
        __structuredAttrs = true;
        strictDeps = true;
        nativeBuildInputs = [
          main
          patchelf
        ];
        inherit runpathEntries;
      }
      ''
        set -eu
        nixLog "Copying main"
        install -Dm755 "${main}/bin/main" ./main

        nixLog "Removing any existing runpath entries from main"
        patchelf --remove-rpath main

        nixLog "Adding runpath entries from runpathEntries to main"
        local entry
        for entry in "''${runpathEntries[@]}"; do
          nixLog "Adding rpath entry for $entry"
          patchelf --add-rpath "$entry" main
        done
        unset entry

        nixLog "Installing main to $out/bin"
        install -Dm755 main "$out/bin/main"
      '';
in
{
  inherit main;

  a = testRunpath {
    drv = mainWithRunpath [ "/a" ];
    included = [ "/a" ];
    excluded = [ "/b" ];
  };

  b = testRunpath {
    drv = mainWithRunpath [ "/b" ];
    included = [ "/b" ];
  };

  c = testRunpath {
    drv = mainWithRunpath [ "/c" ];
    included = [ "/c" ];
    excluded = [ "/a" ];
  };

  a-b-c = testRunpath {
    drv = mainWithRunpath [
      "/a"
      "/b"
      "/c"
    ];
    # Order doesn't matter
    included = [
      "/b"
      "/a"
    ];
    precedes = {
      "/a" = [
        "/c"
        "/b"
      ];
      "/b" = [ "/c" ];
    };
    succeeds = {
      "/c" = [
        "/a"
        "/b"
      ];
      "/b" = [ "/a" ];
    };
  };

  a-when-not-d-positive = testRunpath {
    drv = mainWithRunpath [ "/a" ];
    includedWhenAnyIncluded = {
      "/a" = [ "/d" ];
    };
  };

  a-when-not-d-negative = testBuildFailure' {
    drv = mainWithRunpath [ "/a" ];
    includedWhenAnyIncluded = {
      "/a" = [ "/d" ];
    };
    expectedBuilderLogEntries = [
      "ERROR: runpath entry '/a' is present when any of the following are present: '/d'"
    ];
  };
  # # NOTE: This particular test is used in the docs:
  # # See https://nixos.org/manual/nixpkgs/unstable/#tester-testEqualArrayOrMap
  # # or doc/build-helpers/testers.chapter.md
  # docs-test-function-add-cowbell = testEqualArrayOrMap {
  #   name = "test-function-add-cowbell";
  #   valuesArray = [
  #     "cowbell"
  #     "cowbell"
  #   ];
  #   expectedArray = [
  #     "cowbell"
  #     "cowbell"
  #     "cowbell"
  #   ];
  #   script = ''
  #     addCowbell() {
  #       local -rn arrayNameRef="$1"
  #       arrayNameRef+=( "cowbell" )
  #     }

  #     nixLog "appending all values in valuesArray to actualArray"
  #     for value in "''${valuesArray[@]}"; do
  #       actualArray+=( "$value" )
  #     done

  #     nixLog "applying addCowbell"
  #     addCowbell actualArray
  #   '';
  # };
  # array-append = testEqualArrayOrMap {
  #   name = "testEqualArrayOrMap-array-append";
  #   valuesArray = [
  #     "apple"
  #     "bee"
  #     "cat"
  #   ];
  #   expectedArray = [
  #     "apple"
  #     "bee"
  #     "cat"
  #     "dog"
  #   ];
  #   script = ''
  #     ${concatValuesArrayToActualArray}
  #     actualArray+=( "dog" )
  #   '';
  # };
  # array-prepend = testEqualArrayOrMap {
  #   name = "testEqualArrayOrMap-array-prepend";
  #   valuesArray = [
  #     "apple"
  #     "bee"
  #     "cat"
  #   ];
  #   expectedArray = [
  #     "dog"
  #     "apple"
  #     "bee"
  #     "cat"
  #   ];
  #   script = ''
  #     actualArray+=( "dog" )
  #     ${concatValuesArrayToActualArray}
  #   '';
  # };
  # array-empty = testEqualArrayOrMap {
  #   name = "testEqualArrayOrMap-array-empty";
  #   valuesArray = [
  #     "apple"
  #     "bee"
  #     "cat"
  #   ];
  #   expectedArray = [ ];
  #   script = ''
  #     # doing nothing
  #   '';
  # };
  # array-missing-value = testBuildFailure' {
  #   drv = testEqualArrayOrMap {
  #     name = "testEqualArrayOrMap-array-missing-value";
  #     valuesArray = [ "apple" ];
  #     expectedArray = [ ];
  #     script = concatValuesArrayToActualArray;
  #   };
  #   expectedBuilderLogEntries = [
  #     "ERROR: assertEqualArray: arrays differ in length: expectedArray has length 0 but actualArray has length 1"
  #     "ERROR: assertEqualArray: arrays differ at index 0: expectedArray has no such index but actualArray has value 'apple'"
  #   ];
  # };
  # map-insert = testEqualArrayOrMap {
  #   name = "testEqualArrayOrMap-map-insert";
  #   valuesMap = {
  #     apple = "0";
  #     bee = "1";
  #     cat = "2";
  #   };
  #   expectedMap = {
  #     apple = "0";
  #     bee = "1";
  #     cat = "2";
  #     dog = "3";
  #   };
  #   script = ''
  #     ${concatValuesMapToActualMap}
  #     actualMap["dog"]="3"
  #   '';
  # };
  # map-remove = testEqualArrayOrMap {
  #   name = "testEqualArrayOrMap-map-remove";
  #   valuesMap = {
  #     apple = "0";
  #     bee = "1";
  #     cat = "2";
  #     dog = "3";
  #   };
  #   expectedMap = {
  #     apple = "0";
  #     cat = "2";
  #     dog = "3";
  #   };
  #   script = ''
  #     ${concatValuesMapToActualMap}
  #     unset 'actualMap[bee]'
  #   '';
  # };
  # map-missing-key = testBuildFailure' {
  #   drv = testEqualArrayOrMap {
  #     name = "testEqualArrayOrMap-map-missing-key";
  #     valuesMap = {
  #       bee = "1";
  #       cat = "2";
  #       dog = "3";
  #     };
  #     expectedMap = {
  #       apple = "0";
  #       bee = "1";
  #       cat = "2";
  #       dog = "3";
  #     };
  #     script = concatValuesMapToActualMap;
  #   };
  #   expectedBuilderLogEntries = [
  #     "ERROR: assertEqualMap: maps differ in length: expectedMap has length 4 but actualMap has length 3"
  #     "ERROR: assertEqualMap: maps differ at key 'apple': expectedMap has value '0' but actualMap has no such key"
  #   ];
  # };
  # map-missing-key-with-empty = testBuildFailure' {
  #   drv = testEqualArrayOrMap {
  #     name = "testEqualArrayOrMap-map-missing-key-with-empty";
  #     valuesArray = [ ];
  #     expectedMap.apple = 1;
  #     script = "";
  #   };
  #   expectedBuilderLogEntries = [
  #     "ERROR: assertEqualMap: maps differ in length: expectedMap has length 1 but actualMap has length 0"
  #     "ERROR: assertEqualMap: maps differ at key 'apple': expectedMap has value '1' but actualMap has no such key"
  #   ];
  # };
  # map-extra-key = testBuildFailure' {
  #   drv = testEqualArrayOrMap {
  #     name = "testEqualArrayOrMap-map-extra-key";
  #     valuesMap = {
  #       apple = "0";
  #       bee = "1";
  #       cat = "2";
  #       dog = "3";
  #     };
  #     expectedMap = {
  #       apple = "0";
  #       bee = "1";
  #       dog = "3";
  #     };
  #     script = concatValuesMapToActualMap;
  #   };
  #   expectedBuilderLogEntries = [
  #     "ERROR: assertEqualMap: maps differ in length: expectedMap has length 3 but actualMap has length 4"
  #     "ERROR: assertEqualMap: maps differ at key 'cat': expectedMap has no such key but actualMap has value '2'"
  #   ];
  # };
}
