# NOTE: Tests for cudaRunpathFixup go here.
{
  cudaRunpathFixupHook,
  lib,
  mkCheckExpectedRunpath,
}:
let
  inherit (cudaRunpathFixupHook.passthru.substitutions) cudaCompatLibDir cudaStubLibDir driverLibDir;
  inherit (lib.attrsets) optionalAttrs;

  check = mkCheckExpectedRunpath.overrideAttrs (prevAttrs: {
    nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [ cudaRunpathFixupHook ];
    checkSetupScript = ''
      nixLog "running cudaRunpathFixup on main"
      cudaRunpathFixup main
    '';
  });
in
# TODO: Jetson tests (cudaCompatLibDir).
{
  no-rpath-change = check.overrideAttrs {
    name = "no-rpath-change";
    valuesArr = [ "cat" ];
    expectedArr = [ "cat" ];
  };

  no-deduplication-of-non-cuda-entries = check.overrideAttrs {
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

  cudaStubLibDir-is-replaced-with-driverLibDir = check.overrideAttrs {
    name = "cudaStubLibDir-is-replaced-with-driverLibDir";
    valuesArr = [
      "cat"
      cudaStubLibDir
      "cat"
    ];
    expectedArr = [
      "cat"
      driverLibDir
      "cat"
    ];
  };

  cudaStubLibDir-is-replaced-with-driverLibDir-and-deduplicated = check.overrideAttrs {
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
    expectedArr = [
      "dog"
      driverLibDir
      "bee"
      "frog"
    ];
  };

  driverLibDir-first-then-cudaStubLibDir = check.overrideAttrs {
    name = "driverLibDir-first-then-cudaStubLibDir";
    valuesArr = [
      driverLibDir
      cudaStubLibDir
    ];
    expectedArr = [ driverLibDir ];
  };
}
// optionalAttrs (cudaCompatLibDir != "") {
  cudaCompatLibDir-is-placed-before-driverLibDir = check.overrideAttrs {
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
