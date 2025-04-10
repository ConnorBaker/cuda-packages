{
  fetchFromGitHub,
  lib,
  onnxruntime,
}:
let
  inherit (lib.trivial) warnIf;
in
fetchFromGitHub {
  owner = "dmlc";
  repo = "dlpack";
  tag = "v0.6";
  hash = "sha256-YJdZ0cMtUncH5Z6TtAWBH0xtAIu2UcbjnVcCM4tfg20=";
  meta.broken =
    let
      versionDoesntMatchExpected = onnxruntime.version != "1.21.0";
    in
    warnIf versionDoesntMatchExpected
      # https://github.com/microsoft/onnxruntime/blob/c4fb724e810bb496165b9015c77f402727392933/cmake/deps.txt
      "Update the hash in onnxruntime/dlpack.nix to match the version onnxruntime specifies in cmake/deps.txt"
      versionDoesntMatchExpected;
}
