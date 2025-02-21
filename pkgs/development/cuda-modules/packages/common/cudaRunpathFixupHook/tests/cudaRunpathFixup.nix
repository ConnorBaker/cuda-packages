# NOTE: Tests for cudaRunpathFixup go here.
{
  cudaRunpathFixupHook,
  lib,
  mkCheckExpectedRunpath,
}:
let
  inherit (cudaRunpathFixupHook.passthru.substitutions) cudaCompatLibDir cudaStubLibDir driverLibDir;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.lists) optionals;

  check =
    {
      name,
      valuesArray,
      expectedArray,
    }:
    mkCheckExpectedRunpath.overrideAttrs (prevAttrs: {
      inherit valuesArray expectedArray;
      name = "${cudaRunpathFixupHook.name}-${name}";
      nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [ cudaRunpathFixupHook ];
      script = ''
        nixLog "running cudaRunpathFixup on main"
        cudaRunpathFixup main
      '';
    });
in
# TODO: Jetson tests (cudaCompatLibDir).
{
  no-rpath-change = check {
    name = "no-rpath-change";
    valuesArray = [ "cat" ];
    expectedArray = [ "cat" ];
  };

  no-deduplication-of-non-cuda-entries = check {
    name = "no-deduplication-of-non-cuda-entries";
    valuesArray = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
    expectedArray = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
  };

  cudaStubLibDir-is-replaced-with-driverLibDir = check {
    name = "cudaStubLibDir-is-replaced-with-driverLibDir";
    valuesArray = [
      "cat"
      cudaStubLibDir
      "cat"
    ];
    expectedArray =
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
    valuesArray = [
      "dog"
      cudaStubLibDir
      "bee"
      cudaStubLibDir
      driverLibDir
      "frog"
    ];
    # driverLibDir is before bee because it was transformed from the cudaStubLibDir entry.
    expectedArray =
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
    valuesArray = [
      driverLibDir
      cudaStubLibDir
    ];
    # cudaCompat is present before driverLibDir if it is in the package set
    expectedArray = optionals (cudaCompatLibDir != "") [ cudaCompatLibDir ] ++ [ driverLibDir ];
  };
}
// optionalAttrs (cudaCompatLibDir != "") {
  cudaCompatLibDir-is-placed-before-driverLibDir = check {
    name = "cudaCompatLibDir-is-placed-before-driverLibDir";
    valuesArray = [
      "cat"
      driverLibDir
      "dog"
      cudaCompatLibDir
    ];
    # No extra cudaCompatLibDir due to deduplication.
    expectedArray = [
      "cat"
      cudaCompatLibDir
      driverLibDir
      "dog"
    ];
  };
}
