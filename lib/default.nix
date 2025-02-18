# TODO: Shim for Nixpkgs
let
  flakeLock = builtins.fromJSON (builtins.readFile ../flake.lock);
  nixpkgsSrc = builtins.fetchTree flakeLock.nodes.nixpkgs.locked;
in
import "${nixpkgsSrc}/lib"
