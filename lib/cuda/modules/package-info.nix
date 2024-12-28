{ lib }:
let
  inherit (lib.cuda.types) features sriHash;
  inherit (lib.cuda.utils) mkOptionsModule;
  inherit (lib.types) nonEmptyStr nullOr;
in
mkOptionsModule {
  features = {
    description = "Features the package provides";
    type = features;
  };
  recursiveHash = {
    description = "Recursive NAR hash of the unpacked tarball";
    type = sriHash;
  };
  relativePath = {
    description = "The path to the package in the redistributable tree or null if it can be reconstructed.";
    type = nullOr nonEmptyStr;
    default = null;
  };
}
