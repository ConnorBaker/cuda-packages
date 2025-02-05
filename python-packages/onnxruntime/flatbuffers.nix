{
  fetchFromGitHub,
  lib,
  onnxruntime,
}:
let
  inherit (lib.trivial) warnIf;
in
fetchFromGitHub {
  owner = "google";
  repo = "flatbuffers";
  tag = "v23.5.26";
  hash = "sha256-e+dNPNbCHYDXUS/W+hMqf/37fhVgEGzId6rhP3cToTE=";
  meta.broken =
    let
      versionDoesntMatchExpected = onnxruntime.version != "1.20.1-unstable-2024-12-03";
    in
    warnIf versionDoesntMatchExpected
      # https://github.com/microsoft/onnxruntime/blob/c4fb724e810bb496165b9015c77f402727392933/cmake/deps.txt
      "Update the hash in onnxruntime/eigen.nix to match the version onnxruntime specifies in cmake/deps.txt"
      versionDoesntMatchExpected;
}
