{ lib, flags }:
let
  inherit (lib.lists) optionals;
in
prevAttrs: {
  autoPatchelfIgnoreMissingDeps =
    prevAttrs.autoPatchelfIgnoreMissingDeps or [ ]
    ++ optionals flags.isJetsonBuild [
      "libnvcudla.so"
    ];
}
