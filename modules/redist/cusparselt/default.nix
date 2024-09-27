{ cuda-lib, lib, ... }:
let
  inherit (lib.attrsets) mapAttrs';
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.options) mkOption;
  inherit (lib.strings) removeSuffix;
  inherit (lib.trivial) importJSON;
in
{
  options.redist.cusparselt = mkOption {
    description = "Redist configuration for cusparselt";
    type = cuda-lib.types.redistConfig;
  };

  config.redist.cusparselt = {
    versionPolicy = "minor";
    overrides = packagesFromDirectoryRecursive {
      # Function which loads the file as a Nix expression and ignores the second argument.
      # NOTE: We don't actually want to callPackage these functions at this point, so we use builtins.import
      # instead. We do, however, have to match the callPackage signature.
      callPackage = path: _: builtins.import path;
      directory = ./overrides;
    };
    data = mapAttrs' (filename: _: {
      name = removeSuffix ".json" filename;
      value = importJSON (./data + "/${filename}");
    }) (builtins.readDir ./data);
  };
}
