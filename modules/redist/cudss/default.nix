{ cuda-lib, lib, ... }:
let
  inherit (lib.attrsets) mapAttrs';
  inherit (lib.options) mkOption;
  inherit (lib.strings) removeSuffix;
  inherit (lib.trivial) importJSON;
in
{
  options.redist.cudss = mkOption {
    description = "Redist configuration for CUDSS";
    type = cuda-lib.types.redistConfig;
  };

  config.redist.cudss = {
    versionPolicy = "minor";
    overrides = { };
    data = mapAttrs' (filename: _: {
      name = removeSuffix ".json" filename;
      value = importJSON (./data + "/${filename}");
    }) (builtins.readDir ./data);
  };
}
