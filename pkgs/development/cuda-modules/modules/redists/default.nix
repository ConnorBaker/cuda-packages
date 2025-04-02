{
  config,
  cudaLib,
  lib,
  ...
}:
let
  inherit (builtins) readDir;
  inherit (cudaLib.types) redistName redists;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets) attrNames mapAttrs;
  inherit (lib.lists) concatMap optionals;
  inherit (lib.options) mkOption;

  dir = readDir ./.;

  mkRedistConfigs =
    {
      redistName,
      fixupFnDir,
      genericConfig,
    }:
    let
      fixupFnDirContents = readDir fixupFnDir;
    in
    {
      config.redists.${redistName} = mapAttrs (
        manifestVersion: manifest:
        mapAttrs
          (packageName: redistBuilderArgs: {
            inherit redistName;
            packageName = redistBuilderArgs.packageName or packageName;
            outputs = redistBuilderArgs.outputs or [ "out" ];
            fixupFn =
              # Use the fixup function from the redistBuilderArgs if it exists.
              if redistBuilderArgs.fixupFn or null != null then
                redistBuilderArgs.fixupFn
              # Otherwise, use fixup function of the same name if it exists as a nix expression.
              else if fixupFnDirContents.${packageName + ".nix"} or null == "regular" then
                fixupFnDir + "/${packageName}.nix"
              # If a directory of the same name exists, it is assumed to be callPackage-able (it contains a default.nix).
              else if fixupFnDirContents.${packageName} or null == "directory" then
                fixupFnDir + "/${packageName}"
              else
                (
                  _: _: _:
                  { }
                );
          })
          (genericConfig {
            inherit
              config
              lib
              cudaLib
              manifestVersion
              manifest
              redistName
              ;
          })
      ) config.manifests.${redistName};
    };
in
{
  # Imports from the directory
  imports = concatMap (
    pathName:
    optionals (dir.${pathName} == "directory") (
      assert assertMsg (redistName.check pathName) "Expected a redist name but got ${pathName}";
      [
        (mkRedistConfigs {
          redistName = pathName;
          fixupFnDir = ./. + "/${pathName}";
          genericConfig = import (./. + "/${pathName}");
        })
      ]
    )
  ) (attrNames dir);

  options.redists = mkOption {
    description = "A mapping from redist name to manifest version to redistBuilderArgs configurations";
    type = redists;
    default = { };
  };
}
