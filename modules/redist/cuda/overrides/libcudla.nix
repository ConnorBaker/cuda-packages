{ cudaAtLeast, lib }:
let
  inherit (lib.lists) optionals;
in
prevAttrs: {
  autoPatchelfIgnoreMissingDeps =
    prevAttrs.autoPatchelfIgnoreMissingDeps
    ++ [
      "libnvdla_runtime.so"
    ]
    ++ optionals (cudaAtLeast "12.0") [
      "libnvcudla.so"
    ];
}
