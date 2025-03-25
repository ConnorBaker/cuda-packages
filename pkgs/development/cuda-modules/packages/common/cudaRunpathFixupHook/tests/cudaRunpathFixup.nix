# NOTE: Tests for cudaRunpathFixup go here.
{
  arrayUtilities,
  cudaRunpathFixupHook,
  lib,
  testers,
}:
let
  inherit (arrayUtilities) getRunpathEntries;
  inherit (cudaRunpathFixupHook.passthru.substitutions) cudaCompatLibDir cudaStubLibDir driverLibDir;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.lists) optionals;
  inherit (testers) makeMainWithRunpath testEqualArrayOrMap;

  check =
    {
      name,
      runpathEntries,
      expectedRunpathEntries ? runpathEntries, # default to runpathEntries
    }:
    (testEqualArrayOrMap {
      name = "${cudaRunpathFixupHook.name}-${name}";
      valuesArray = runpathEntries;
      expectedArray = expectedRunpathEntries;
      script = ''
        nixLog "installing main"
        install -Dm677 "${makeMainWithRunpath { inherit runpathEntries; }}/bin/main" main
        nixLog "running cudaRunpathFixup on main"
        cudaRunpathFixup main
        nixLog "populating actualArray"
        getRunpathEntries main actualArray
      '';
    }).overrideAttrs
      (prevAttrs: {
        nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
          getRunpathEntries
          cudaRunpathFixupHook
        ];
      });
in
# TODO: Jetson tests (cudaCompatLibDir).
{
  no-rpath-change = check {
    name = "no-rpath-change";
    runpathEntries = [ "cat" ];
  };

  no-deduplication-of-non-cuda-entries = check {
    name = "no-deduplication-of-non-cuda-entries";
    runpathEntries = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
  };

  cudaStubLibDir-is-replaced-with-driverLibDir = check {
    name = "cudaStubLibDir-is-replaced-with-driverLibDir";
    runpathEntries = [
      "cat"
      cudaStubLibDir
      "cat"
    ];
    expectedRunpathEntries =
      [ "cat" ]
      # cudaCompat is present before driverLibDir if it is in the package set
      ++ optionals (cudaCompatLibDir != "") [ cudaCompatLibDir ]
      ++ [
        driverLibDir
        "cat"
      ];
  };

  cudaStubLibDir-is-replaced-with-driverLibDir-and-deduplicated = check {
    name = "cudaStubLibDir-is-replaced-with-driverLibDir-and-deduplicated";
    runpathEntries = [
      "dog"
      cudaStubLibDir
      "bee"
      cudaStubLibDir
      driverLibDir
      "frog"
    ];
    # driverLibDir is before bee because it was transformed from the cudaStubLibDir entry.
    expectedRunpathEntries =
      [ "dog" ]
      # cudaCompat is present before driverLibDir if it is in the package set
      ++ optionals (cudaCompatLibDir != "") [ cudaCompatLibDir ]
      ++ [
        driverLibDir
        "bee"
        "frog"
      ];
  };

  driverLibDir-first-then-cudaStubLibDir = check {
    name = "driverLibDir-first-then-cudaStubLibDir";
    runpathEntries = [
      driverLibDir
      cudaStubLibDir
    ];
    # cudaCompat is present before driverLibDir if it is in the package set
    expectedRunpathEntries = optionals (cudaCompatLibDir != "") [ cudaCompatLibDir ] ++ [
      driverLibDir
    ];
  };
}
// optionalAttrs (cudaCompatLibDir != "") {
  cudaCompatLibDir-is-placed-before-driverLibDir = check {
    name = "cudaCompatLibDir-is-placed-before-driverLibDir";
    runpathEntries = [
      "cat"
      driverLibDir
      "dog"
      cudaCompatLibDir
    ];
    # No extra cudaCompatLibDir due to deduplication.
    expectedRunpathEntries = [
      "cat"
      cudaCompatLibDir
      driverLibDir
      "dog"
    ];
  };
}
