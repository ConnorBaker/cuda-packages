{
  arrayUtilities,
  lib,
  patchelf,
  makeSetupHook',
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook' {
  name = "runpathFixup";
  script = ./runpathFixup.bash;
  nativeBuildInputs = [
    arrayUtilities.arrayDifference
    arrayUtilities.arrayReplace
    arrayUtilities.arraysAreEqual
    arrayUtilities.getElfFiles
    arrayUtilities.getRunpathEntries
    arrayUtilities.deduplicateArray
    arrayUtilities.isDeclaredArray
    arrayUtilities.isDeclaredMap
    patchelf
  ];
  passthru.tests = { }; # TODO
  meta = {
    description = "Perform runpath fixups";
    maintainers = cuda.members;
  };
}
