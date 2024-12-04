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
  rev = "e7248b26a1ed53fa030c5c459f7ea095dfd276ac";
  hash = "sha256-uQ1YYV3ojbMVfHdqjXRyUymRPjJZV3WHT36PTxPRius=";
  meta.broken =
    let
      versionDoesntMatchExpected = onnxruntime.version != "1.20.1-unstable-2024-12-03";
    in
    warnIf versionDoesntMatchExpected
      # https://github.com/microsoft/onnxruntime/blob/c4fb724e810bb496165b9015c77f402727392933/cmake/deps.txt
      "Update the hash in onnxruntime/eigen.nix to match the version onnxruntime specifies in cmake/deps.txt"
      versionDoesntMatchExpected;
}
