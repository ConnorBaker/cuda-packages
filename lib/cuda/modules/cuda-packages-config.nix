{ lib }:
let
  inherit (lib.cuda.types)
    attrs
    nvccConfig
    redistName
    version
    ;
  inherit (lib.cuda.utils) mkOptions;
  inherit (lib.types)
    listOf
    path
    raw
    ;
in
{
  freeformType = raw;
  options = mkOptions {
    nvcc = {
      description = ''
        Configuration options for nvcc.
      '';
      type = nvccConfig;
      default = { };
    };
    packagesDirectories = {
      description = ''
        Paths to directories containing Nix expressions to add to the package set.

        Package names created from directories later in the list override packages earlier in the list.
      '';
      type = listOf path;
      default = [ ];
    };
    redists = {
      description = ''
        Maps redist name to version.

        Versions must match the format of the corresponding versioned manifest for the redist.

        If a redistributable is not present in this attribute set, it is not included in the package set.

        If the version specified for a redistributable is not present in the corresponding versioned manifest, it is not included in the package set.
      '';
      type = attrs redistName version;
      default = { };
    };
  };
}
