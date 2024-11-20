{ lib, ... }:
let
  inherit (builtins) readDir;
  inherit (lib.attrsets) foldlAttrs optionalAttrs;
  inherit (lib.options) mkOption;
  inherit (lib.cuda.utils) mkRedistConfig;
in
{
  options = {
    redists = mkOption {
      description = "A mapping from redist name to redistConfig";
      type = lib.cuda.types.redists;
      default = foldlAttrs (
        acc: pathName: pathType:
        acc
        // optionalAttrs (pathType == "directory") {
          ${pathName} = mkRedistConfig (./. + "/${pathName}");
        }
      ) { } (readDir ./.);
    };
  };
}
