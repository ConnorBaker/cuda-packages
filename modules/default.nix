{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) readDir;
  inherit (lib.attrsets)
    attrNames
    filterAttrs
    mapAttrs'
    removeAttrs
    ;
  inherit (lib.options) mkOption;
  inherit (lib.strings) hasSuffix replaceStrings;
  inherit (lib.types) lazyAttrsOf raw;
  inherit (lib.trivial) pipe;

  # NOTE: Not recursive.
  getNixFilePathsInDir =
    dir:
    pipe dir [
      readDir
      (filterAttrs (filename: type: hasSuffix ".nix" filename && type == "regular"))
      attrNames
      (map (filename: dir + "/${filename}"))
    ];

  cudaLibModules = getNixFilePathsInDir ./cuda-lib;
  dataModules = getNixFilePathsInDir ./data;
  redistModules = [ ./redist/cuda ];
in
{
  imports = cudaLibModules ++ dataModules ++ redistModules ++ [ ./package-sets.nix ];
}
