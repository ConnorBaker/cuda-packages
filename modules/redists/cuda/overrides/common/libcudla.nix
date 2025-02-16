{ cudaPackagesConfig, lib }:
let
  inherit (lib.lists) optionals;
in
prevAttrs: {
  autoPatchelfIgnoreMissingDeps =
    prevAttrs.autoPatchelfIgnoreMissingDeps or [ ]
    ++ optionals cudaPackagesConfig.hasJetsonCudaCapability [
      "libnvcudla.so"
    ];
}
