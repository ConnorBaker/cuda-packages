{ lib, ... }:
let
  inherit (lib.cuda.types) redists;
  inherit (lib.cuda.utils) mkRedistConfigs;
  inherit (lib.options) mkOption;
in
{
  options.redists = mkOption {
    description = "A mapping from redist name to redistConfig";
    type = redists;
    default = { };
  };
  config.redists = mkRedistConfigs ./.;
}
