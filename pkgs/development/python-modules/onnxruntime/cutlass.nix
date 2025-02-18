{
  fetchFromGitHub,
  lib,
  onnxruntime,
}:
let
  inherit (lib.trivial) warnIf;
in
fetchFromGitHub {
  owner = "NVIDIA";
  repo = "cutlass";
  tag = "v3.5.1";
  hash = "sha256-sTGYN+bjtEqQ7Ootr/wvx3P9f8MCDSSj3qyCWjfdLEA=";
  meta.broken =
    let
      versionDoesntMatchExpected = onnxruntime.version != "1.20.1-unstable-2024-12-03";
    in
    warnIf versionDoesntMatchExpected
      # https://github.com/microsoft/onnxruntime/blob/c4fb724e810bb496165b9015c77f402727392933/cmake/deps.txt
      "Update the hash in onnxruntime/eigen.nix to match the version onnxruntime specifies in cmake/deps.txt"
      versionDoesntMatchExpected;
}
