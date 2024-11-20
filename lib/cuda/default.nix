{ lib }:
let
  inherit (builtins) import;
  inherit (lib.trivial) flip;
  callLibs = flip import { inherit lib; };
in
{
  data = import ./data.nix;
  types = callLibs ./types.nix;
  utils = callLibs ./utils.nix;
}
