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
  name = "getElfFiles";
  script = ./getElfFiles.bash;
  propagatedBuildInputs = [
    isDeclaredArray
    patchelf
  ];
  # TODO
  # passthru.tests = callPackages ./tests.nix {};
  meta = {
    description = "Populates a reference to an array with paths to ELF files in a given directory";
    maintainers = cuda.members;
  };
}
