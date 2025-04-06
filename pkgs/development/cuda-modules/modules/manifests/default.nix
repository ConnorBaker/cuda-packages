{ cudaLib, lib, ... }:
let
  inherit (builtins) readDir;
  inherit (cudaLib.types) attrs redistName version;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets) foldlAttrs optionalAttrs;
  inherit (lib.options) mkOption;
  inherit (lib.strings)
    removeSuffix
    removePrefix
    ;
  inherit (lib.types) anything;
  inherit (lib.trivial) pipe importJSON;

  mkVersionedManifests =
    path:
    foldlAttrs (
      acc: pathName: pathType:
      let
        version = pipe pathName [
          (removePrefix "redistrib_")
          (removeSuffix ".json")
        ];
        isRedistribFile = pathType == "regular" && version != pathName;
      in
      acc // optionalAttrs isRedistribFile { ${version} = importJSON (path + "/${pathName}"); }
    ) { } (readDir path);

  mkManyManifests =
    path:
    foldlAttrs (
      acc: pathName: pathType:
      acc
      // optionalAttrs (pathType == "directory") (
        assert assertMsg (redistName.check pathName) "Expected a redist name but got ${pathName}";
        {
          ${pathName} = mkVersionedManifests (path + "/${pathName}");
        }
      )
    ) { } (readDir path);
in
{
  options.manifests = mkOption {
    description = "A mapping from redistrib name to manifest version to manifest";
    type = attrs redistName (attrs version anything);
  };
  config.manifests = mkManyManifests ./.;
}
