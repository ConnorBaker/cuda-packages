{ lib }:
let
  inherit (builtins) import;
  inherit (lib.trivial) flip;
in
lib.extend (
  final: _:
  let
    callLibs = flip import { lib = final; };
  in
  {
    cuda = callLibs ./cuda;
    upstreamable = callLibs ./upstreamable;
  }
)
