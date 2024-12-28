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
  repo = "cccl";
  tag = "v2.7.0-rc2";
  hash = "sha256-BgVE9DpGG+vIc3SfAv826z3dZiKxl2uGqhj47hp3SVM=";
  meta.broken =
    let
      versionDoesntMatchExpected = matx.version != "0.9.0-unstable-2024-11-15";
    in
    warnIf versionDoesntMatchExpected
      "Update the hash in matx/cccl.nix to match the version MatX specifies through rapids-cmake"
      versionDoesntMatchExpected;
}
