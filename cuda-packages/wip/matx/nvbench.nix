{
  fetchFromGitHub,
  lib,
  matx,
}:
let
  inherit (lib.trivial) warnIf;
in
fetchFromGitHub {
  owner = "NVIDIA";
  repo = "nvbench";
  rev = "555d628e9b250868c9da003e4407087ff1982e8e";
  hash = "sha256-M6XUr2BjnT38I30+OveFEDJXOCGoACrY9uRVVW4a6Qw=";
  meta.broken =
    let
      versionDoesntMatchExpected = matx.version != "0.9.0-unstable-2024-11-15";
    in
    warnIf versionDoesntMatchExpected
      "Update the hash in matx/nvbench.nix to match the version MatX specifies through rapids-cmake"
      versionDoesntMatchExpected;
}
