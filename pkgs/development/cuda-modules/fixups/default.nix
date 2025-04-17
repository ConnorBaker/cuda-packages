{ cudaLib, lib }:
let
  inherit (builtins) readDir;
  inherit (cudaLib.types) redistName;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets) foldlAttrs optionalAttrs;
  inherit (lib.trivial) pathExists;
  inherit (lib.strings) hasSuffix removeSuffix;

  mkFixups =
    fixupFnDir:
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
    ) { } (readDir fixupFnDir);
in
foldlAttrs (
  acc: fileName: fileType:
  acc
  // optionalAttrs (fileType == "directory") (
    assert assertMsg (redistName.check fileName) "expected a redist name but got ${fileName}";
    {
      ${fileName} = mkFixups (./. + "/${fileName}");
    }
  )
) { } (readDir ./.)
