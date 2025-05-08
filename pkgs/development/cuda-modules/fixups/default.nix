{ lib }:

lib.concatMapAttrs (
  fileName: _type:
  let
    # Fixup is in `./${attrName}.nix` or in `./${fileName}/default.nix`:
    attrName = lib.removeSuffix ".nix" fileName;
    value = import (./. + "/${fileName}");
    isFixup = fileName != "default.nix";
  in
  lib.optionalAttrs isFixup { ${attrName} = value; }
) (builtins.readDir ./.)
