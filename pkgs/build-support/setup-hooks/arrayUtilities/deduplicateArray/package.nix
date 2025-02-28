{
  callPackages,
  isDeclaredArray,
  isDeclaredMap,
  lib,
  makeSetupHook',
}:
let
  inherit (lib.teams) cuda;
in
makeSetupHook' {
  name = "deduplicateArray";
  script = ./deduplicateArray.bash;
  scriptNativeBuildInputs = [
    isDeclaredArray
    isDeclaredMap
  ];
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Removes duplicate elements from an array";
    maintainers = cuda.members;
  };
}
