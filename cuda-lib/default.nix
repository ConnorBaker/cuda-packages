{ lib, pkgs }:
let
  inherit (builtins) import;
  inherit (lib.fixedPoints) makeExtensible;

  cuda-lib = makeExtensible (final: {
    data = import ./data.nix;
    types = import ./types.nix {
      inherit lib;
      cuda-lib = final;
    };
    utils = import ./utils.nix {
      inherit pkgs lib;
      cuda-lib = final;
    };
  });
in
cuda-lib
