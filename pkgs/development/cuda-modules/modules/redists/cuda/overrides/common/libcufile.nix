{
  cuda_cudart,
  lib,
  numactl,
  rdma-core,
}:
let
  inherit (lib.attrsets) getOutput;
in
prevAttrs: {
  allowFHSReferences = true;
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    (getOutput "stubs" cuda_cudart)
    numactl
    rdma-core
  ];
}
