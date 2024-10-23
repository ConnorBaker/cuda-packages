{ lib }:
let
  inherit (builtins) import;
  inherit (lib.fixedPoints) makeExtensible;
  upstreamable-lib = import ../upstreamable-lib { inherit lib; };
in
makeExtensible (final: {
  data = import ./data.nix;
  types = import ./types.nix {
    inherit lib upstreamable-lib;
    cuda-lib = final;
  };
  utils = import ./utils.nix {
    inherit lib upstreamable-lib;
    cuda-lib = final;
  };
})
