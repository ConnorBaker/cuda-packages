{ lib, flags }:
let
  inherit (lib.lists) optionals;
in
prevAttrs: {
  autoPatchelfIgnoreMissingDeps =
    prevAttrs.autoPatchelfIgnoreMissingDeps or [ ]
    ++ optionals flags.isJetsonBuild [
      "libnvdla_runtime.so"
    ];
}
