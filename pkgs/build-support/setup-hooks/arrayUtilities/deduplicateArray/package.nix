{
  callPackages,
  isDeclaredArray,
  isDeclaredMap,
  lib,
  makeBashFunction,
}:
let
  inherit (lib.teams) cuda;
in
makeBashFunction {
  name = "deduplicateArray";
  script = ./deduplicateArray.bash;
  propagatedBuildInputs = [
    isDeclaredArray
    isDeclaredMap
  ];
  passthru.tests = callPackages ./tests.nix { };
  meta = {
    description = "Removes duplicate elements from an array";
    maintainers = cuda.members;
  };
}
