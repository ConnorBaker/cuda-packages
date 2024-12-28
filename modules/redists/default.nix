{ lib, ... }:
let
  inherit (builtins) readDir;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets) foldlAttrs optionalAttrs;
  inherit (lib.cuda.types) redistName redists;
  inherit (lib.cuda.utils) mkRedistConfig;
  inherit (lib.options) mkOption;
in
{
  options.redists = mkOption {
    description = "A mapping from redist name to redistConfig";
    type = redists;
    default = { };
  };
  config.redists = foldlAttrs (
    acc: pathName: pathType:
    acc
    // optionalAttrs (pathType == "directory") (
      assert assertMsg (redistName.check pathName) "Expected a redist name but got ${pathName}";
      {
        ${pathName} = mkRedistConfig (./. + "/${pathName}");
      }
    )
  ) { } (readDir ./.);
}
