{
  cudaLib,
  lib,
  ...
}:
let
  inherit (builtins) readDir;
  inherit (cudaLib.types) redistName fixups;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets)
    foldlAttrs
    optionalAttrs
    ;
  inherit (lib.options) mkOption;
  inherit (lib.strings) hasSuffix removeSuffix;
  inherit (lib.trivial) pathExists;

  mkFixupsForRedist =
    {
      redistName,
      fixupFnDir,
    }:
    let
      fixupFnDirContents = readDir fixupFnDir;
    in
    foldlAttrs (
      acc: fileName: fileType:
      let
        packageName =
          if fileType == "directory" then
            let
              pathToDefaultNix = fixupFnDir + "/${fileName}/default.nix";
            in
            assert assertMsg (pathExists pathToDefaultNix) "expected file ${pathToDefaultNix} does not exist!";
            fileName
          else
            let
              pathToFile = fixupFnDir + "/${fileName}";
            in
            assert assertMsg (hasSuffix ".nix" fileName) "expected file to have a .nix suffix: ${pathToFile}";
            removeSuffix ".nix" fileName;
      in
      acc
      // {
        ${packageName} = fixupFnDir + "/${fileName}";
      }
    ) { } fixupFnDirContents;
in
{
  options.fixups = mkOption {
    description = "A mapping from redist name to package name to fixup function";
    type = fixups;
    default = { };
  };

  config.fixups = foldlAttrs (
    acc: fileName: fileType:
    acc
    // optionalAttrs (fileType == "directory") (
      assert assertMsg (redistName.check fileName) "expected a redist name but got ${fileName}";
      {
        ${fileName} = mkFixupsForRedist {
          redistName = fileName;
          fixupFnDir = ./. + "/${fileName}";
        };
      }
    )
  ) { } (readDir ./.);
}
