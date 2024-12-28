{ lib }:
let
  inherit (lib.cuda.types) version;
  inherit (lib.cuda.utils) mkOptionsModule;
  inherit (lib.types) nonEmptyStr nullOr;
in
mkOptionsModule {
  licensePath = {
    description = "The path to the license file in the redistributable tree";
    type = nullOr nonEmptyStr;
    default = null;
  };
  license = {
    description = "The license of the redistributable";
    type = nullOr nonEmptyStr;
  };
  name = {
    description = "The full name of the redistributable";
    type = nullOr nonEmptyStr;
  };
  version = {
    description = "The version of the redistributable";
    type = version;
  };
}
