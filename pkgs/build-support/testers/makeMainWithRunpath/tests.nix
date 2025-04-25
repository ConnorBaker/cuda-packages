# NOTE: We must use `pkgs.runCommand` instead of `testers.runCommand` for negative tests -- those wrapped with
# `testers.testBuildFailure'`. This is due to the fact that `testers.testBuildFailure'` modifies the derivation such that
# it produces an output containing the exit code, logs, and other things. Since `testers.runCommand` expects the empty
# derivation, it produces a hash mismatch.
{
  arrayUtilities,
  lib,
  testers,
}:
let
  inherit (arrayUtilities) getRunpathEntries;
  inherit (lib.attrsets) recurseIntoAttrs;
  inherit (testers) makeMainWithRunpath testEqualArrayOrMap testBuildFailure';

  check =
    {
      name,
      runpathEntries,
      expectedRunpathEntries ? runpathEntries, # Default to the same as runpathEntries
    }:
    (testEqualArrayOrMap {
      name = "makeMainWithRunpath-${name}";
      valuesArray = runpathEntries;
      expectedArray = expectedRunpathEntries;
      script = ''
        nixLog "populating actualArray"
        getRunpathEntries "${makeMainWithRunpath { inherit runpathEntries; }}/bin/main" actualArray
      '';
    }).overrideAttrs
      (prevAttrs: {
        nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
          getRunpathEntries
        ];
      });
in
recurseIntoAttrs {
  a = check {
    name = "a";
    runpathEntries = [ "/a" ];
  };

  a-failure = testBuildFailure' {
    drv = check {
      name = "a-expects-b";
      runpathEntries = [ "/a" ];
      expectedRunpathEntries = [ "/b" ];
    };
    expectedBuilderLogEntries = [
      "ERROR: assertEqualArray: arrays differ at index 0: expectedArray has value '/b' but actualArray has value '/a'"
    ];
  };

  a-b = check {
    name = "a-b";
    runpathEntries = [
      "/a"
      "/b"
    ];
  };

  a-b-failure-b-a = testBuildFailure' {
    drv = check {
      name = "a-b-expects-b-a";
      runpathEntries = [
        "/a"
        "/b"
      ];
      expectedRunpathEntries = [
        "/b"
        "/a"
      ];
    };
    expectedBuilderLogEntries = [
      "ERROR: assertEqualArray: arrays differ at index 0: expectedArray has value '/b' but actualArray has value '/a'"
      "ERROR: assertEqualArray: arrays differ at index 1: expectedArray has value '/a' but actualArray has value '/b'"
    ];
  };

  a-b-failure-a-a = testBuildFailure' {
    drv = check {
      name = "a-b-expects-a-a";
      runpathEntries = [
        "/a"
        "/b"
      ];
      expectedRunpathEntries = [
        "/a"
        "/a"
      ];
    };
    expectedBuilderLogEntries = [
      "ERROR: assertEqualArray: arrays differ at index 1: expectedArray has value '/a' but actualArray has value '/b'"
    ];
  };

  a-b-failure-b-b = testBuildFailure' {
    drv = check {
      name = "a-b-expects-b-b";
      runpathEntries = [
        "/a"
        "/b"
      ];
      expectedRunpathEntries = [
        "/b"
        "/b"
      ];
    };
    expectedBuilderLogEntries = [
      "ERROR: assertEqualArray: arrays differ at index 0: expectedArray has value '/b' but actualArray has value '/a'"
    ];
  };

  # Check no deduplication
  a-a = check {
    name = "a-a";
    runpathEntries = [
      "/a"
      "/a"
    ];
  };
}
