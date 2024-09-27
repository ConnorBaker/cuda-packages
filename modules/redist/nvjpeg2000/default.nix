{ cuda-lib, lib, ... }:
let
  inherit (lib.attrsets) mapAttrs';
  inherit (lib.options) mkOption;
  inherit (lib.strings) removeSuffix;
  inherit (lib.trivial) importJSON;
in
{
  options.redist.nvjpeg2000 = mkOption {
    description = "Redist configuration for nvjpeg2000";
    type = cuda-lib.types.redistConfig;
  };

  config.redist.nvjpeg2000 = {
    versionPolicy = "minor";
    overrides = { };
    data = mapAttrs' (filename: _: {
      name = removeSuffix ".json" filename;
      value = importJSON (./data + "/${filename}");
    }) (builtins.readDir ./data);
  };
}
