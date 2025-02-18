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
      valuesArr,
      expectedArr,
    }:
    mkCheckExpectedRunpath.overrideAttrs (prevAttrs: {
      inherit valuesArr expectedArr;
      name = "${cudaRunpathFixupHook.name}-${name}";
      nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [ cudaRunpathFixupHook ];
      checkSetupScript = ''
        nixLog "running cudaRunpathFixup on main"
        cudaRunpathFixup main
      '';
    });
in
# TODO: Jetson tests (cudaCompatLibDir).
{
  no-rpath-change = check {
    name = "no-rpath-change";
    valuesArr = [ "cat" ];
    expectedArr = [ "cat" ];
  };

  no-deduplication-of-non-cuda-entries = check {
    name = "no-deduplication-of-non-cuda-entries";
    valuesArr = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
    expectedArr = [
      "bee"
      "apple"
      "dog"
      "apple"
      "cat"
    ];
  };

  cudaStubLibDir-is-replaced-with-driverLibDir = check {
    name = "cudaStubLibDir-is-replaced-with-driverLibDir";
    valuesArr = [
      "cat"
      cudaStubLibDir
      "cat"
    ];
    expectedArr =
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
    valuesArr = [
      "dog"
      cudaStubLibDir
      "bee"
      cudaStubLibDir
      driverLibDir
      "frog"
    ];
    # driverLibDir is before bee because it was transformed from the cudaStubLibDir entry.
    expectedArr =
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
    valuesArr = [
      driverLibDir
      cudaStubLibDir
    ];
    # cudaCompat is present before driverLibDir if it is in the package set
    expectedArr = optionals (cudaCompatLibDir != "") [ cudaCompatLibDir ] ++ [ driverLibDir ];
  };
}
// optionalAttrs (cudaCompatLibDir != "") {
  cudaCompatLibDir-is-placed-before-driverLibDir = check {
    name = "cudaCompatLibDir-is-placed-before-driverLibDir";
    valuesArr = [
      "cat"
      driverLibDir
      "dog"
      cudaCompatLibDir
    ];
    # No extra cudaCompatLibDir due to deduplication.
    expectedArr = [
      "cat"
      cudaCompatLibDir
      driverLibDir
      "dog"
    ];
  };
}
