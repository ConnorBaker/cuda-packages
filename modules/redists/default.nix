{ lib, ... }:
let
  inherit (builtins) readDir;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets) foldlAttrs optionalAttrs mapAttrs;
  inherit (lib.modules) mkDefault;
  inherit (lib.options) mkOption;
  inherit (lib.cuda.types) redistName;
  inherit (lib.cuda.utils) mkRedistConfig;
in
{
  options.redists = mkOption {
    description = "A mapping from redist name to redistConfig";
    type = lib.cuda.types.redists;
    default = { };
  };
  config.redists = foldlAttrs (
    acc: pathName: pathType:
    acc
    // optionalAttrs (pathType == "directory") (
      assert assertMsg (redistName.check pathName) "Expected a redist name but got ${pathName}";
      {
        ${pathName} =
          let
            redistConfig = mkRedistConfig (./. + "/${pathName}");
          in
          # Set default priority on all the versions of set of overrides and manifests.
          mapAttrs (_: mapAttrs (_: mkDefault)) redistConfig;
      }
    )
  ) { } (readDir ./.);
}
