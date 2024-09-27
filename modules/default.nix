{ lib, ... }:
let
  inherit (builtins) readDir;
  inherit (lib.attrsets) attrNames filterAttrs;
  inherit (lib.strings) hasSuffix;
  inherit (lib.trivial) pipe;

  # NOTE: Not recursive.
  getNixFilePathsInDir =
    dir:
    pipe dir [
      readDir
      (filterAttrs (name: type: hasSuffix ".nix" name && type == "regular"))
      attrNames
      (map (filename: dir + "/${filename}"))
    ];

  getDirsInDir =
    dir:
    pipe dir [
      readDir
      (filterAttrs (filename: type: type == "directory"))
      attrNames
      (map (dirname: dir + "/${dirname}"))
    ];

  dataModules = getNixFilePathsInDir ./data;
  redistModules = getDirsInDir ./redist;
in
{
  imports = dataModules ++ redistModules ++ [ ./package-sets.nix ];
}
