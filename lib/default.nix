# TODO: Shim for Nixpkgs
(builtins.getFlake (builtins.toString ../.)).inputs.nixpkgs.lib
