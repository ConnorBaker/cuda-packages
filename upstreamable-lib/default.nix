{ lib }:
let
  inherit (builtins) import;
  inherit (lib.fixedPoints) makeExtensible;
in
makeExtensible (final: {
  attrsets = import ./attrsets.nix {
    inherit lib;
    upstreamable-lib = final;
  };
  types = import ./types.nix {
    inherit lib;
    upstreamable-lib = final;
  };
  versions = import ./versions.nix {
    inherit lib;
    upstreamable-lib = final;
  };
})
