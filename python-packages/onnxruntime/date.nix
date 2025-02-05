{
  fetchFromGitHub,
  lib,
  onnxruntime,
}:
let
  inherit (lib.trivial) warnIf;
in
fetchFromGitHub {
  owner = "HowardHinnant";
  repo = "date";
  tag = "v3.0.1";
  hash = "sha256-ZSjeJKAcT7mPym/4ViDvIR9nFMQEBCSUtPEuMO27Z+I=";
  meta.broken =
    let
      versionDoesntMatchExpected = onnxruntime.version != "1.20.1-unstable-2024-12-03";
    in
    warnIf versionDoesntMatchExpected
      # https://github.com/microsoft/onnxruntime/blob/c4fb724e810bb496165b9015c77f402727392933/cmake/deps.txt
      "Update the hash in onnxruntime/eigen.nix to match the version onnxruntime specifies in cmake/deps.txt"
      versionDoesntMatchExpected;
}
