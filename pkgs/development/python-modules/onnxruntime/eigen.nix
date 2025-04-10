{
  fetchFromGitLab,
  lib,
  onnxruntime,
}:
let
  inherit (lib.trivial) warnIf;
in
fetchFromGitLab {
  owner = "libeigen";
  repo = "eigen";
  rev = "1d8b82b0740839c0de7f1242a3585e3390ff5f33";
  hash = "sha256-keMdXlt4S99fx28Kl5tbSIQA2TeKWqV4syd9K2VAsF8=";
  meta.broken =
    let
      versionDoesntMatchExpected = onnxruntime.version != "1.21.0";
    in
    warnIf versionDoesntMatchExpected
      # https://github.com/microsoft/onnxruntime/blob/c4fb724e810bb496165b9015c77f402727392933/cmake/deps.txt
      "Update the hash in onnxruntime/eigen.nix to match the version onnxruntime specifies in cmake/deps.txt"
      versionDoesntMatchExpected;
}
