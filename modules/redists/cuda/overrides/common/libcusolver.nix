{
  lib,
  libcublas,
  libcusparse,
  libnvjitlink,
}:
let
  inherit (lib.attrsets) getLib;
in
prevAttrs: {
  buildInputs = prevAttrs.buildInputs ++ [
    (getLib libcublas)
    (getLib libcusparse)
    libnvjitlink
  ];
}
