{ lib }:
let
  inherit (builtins) import;
  inherit (lib.trivial) flip;
  callLibs = flip import { inherit lib; };
in
{
  attrsets = callLibs ./attrsets.nix;
  strings = callLibs ./strings.nix;
  trivial = callLibs ./trivial.nix;
  types = callLibs ./types.nix;
  versions = callLibs ./versions.nix;
}
