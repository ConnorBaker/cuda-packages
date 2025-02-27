{
  isDeclaredArray,
  lib,
  makeSetupHook',
  patchelf,
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook' {
  name = "getRunpathEntries";
  script = ./getRunpathEntries.bash;
  propagatedBuildInputs = [
    isDeclaredArray
    patchelf
  ];
  # TODO
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Populates a reference to an array with the runpath entries of a given file";
    maintainers = cuda.members;
  };
}
