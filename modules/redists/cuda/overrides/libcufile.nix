{
  lib,
  libcublas,
  numactl,
  rdma-core,
}:
let
  inherit (lib.attrsets) getLib;
in
prevAttrs: {
  allowFHSReferences = true;
  buildInputs = prevAttrs.buildInputs ++ [
    (getLib libcublas)
    numactl
    rdma-core
  ];
}
