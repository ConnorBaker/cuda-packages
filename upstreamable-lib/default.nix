{ lib }:
let
  inherit (builtins) import;
  inherit (lib.fixedPoints) makeExtensible;
in
makeExtensible (_: {
  types = import ./types.nix {
    inherit lib;
  };
  versions = import ./versions.nix {
    inherit lib;
  };
})
