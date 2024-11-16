{
  fetchFromGitHub,
  lib,
  onnxruntime,
}:
let
  inherit (lib.trivial) warnIf;
in
fetchFromGitHub {
  owner = "dcleblanc";
  repo = "safeint";
  rev = "refs/tags/3.0.28";
  hash = "sha256-pjwjrqq6dfiVsXIhbBtbolhiysiFlFTnx5XcX77f+C0=";
  meta.broken =
    let
      versionDoesntMatchExpected = onnxruntime.version != "1.20.0-unstable-2024-11-14";
    in
    warnIf versionDoesntMatchExpected
      # https://github.com/microsoft/onnxruntime/blob/c4fb724e810bb496165b9015c77f402727392933/cmake/deps.txt
      "Update the hash in onnxruntime/eigen.nix to match the version onnxruntime specifies in cmake/deps.txt"
      versionDoesntMatchExpected;
}
