{ lib }:
let
  inherit (lib.cuda.utils) mkOptionsModule;
  inherit (lib.types) nullOr package;
in
mkOptionsModule {
  hostStdenv = {
    description = ''
      The host stdenv compiler to use when building CUDA code.
      This option is used to determine the version of the host compiler to use when building CUDA code.
    '';
    default = null;
    type = nullOr package;
  };
}
