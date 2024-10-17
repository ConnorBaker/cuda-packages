{
  cudaOlder,
  lib,
  libcublas,
  numactl,
  rdma-core,
}:
let
  inherit (lib.attrsets) getLib;
  inherit (lib.lists) optionals;
in
prevAttrs: {
  allowFHSReferences = true;
  buildInputs = prevAttrs.buildInputs ++ [
    (getLib libcublas)
    numactl
    rdma-core
  ];
  # Before 11.7 libcufile depends on itself for some reason.
  autoPatchelfIgnoreMissingDeps =
    prevAttrs.autoPatchelfIgnoreMissingDeps
    ++ optionals (cudaOlder "11.7") [ "libcufile.so.0" ];
}
