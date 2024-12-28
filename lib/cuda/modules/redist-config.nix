{ lib }:
let
  inherit (lib.cuda.types) versionedManifests versionedOverrides;
  inherit (lib.cuda.utils) mkOptionsModule;
in
mkOptionsModule {
  versionedOverrides = {
    description = ''
      Overrides for packages provided by the redistributable.
    '';
    type = versionedOverrides;
  };
  versionedManifests = {
    description = ''
      Data required to produce packages for (potentially multiple) versions of CUDA.
    '';
    type = versionedManifests;
  };
}
