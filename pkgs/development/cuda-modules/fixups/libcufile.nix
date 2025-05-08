{
  cuda_cudart,
  lib,
  numactl,
  rdma-core,
}:
prevAttrs: {
  allowFHSReferences = true;

  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    (lib.getOutput "stubs" cuda_cudart)
    numactl
    rdma-core
  ];

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "dev"
        "include"
        "lib"
        "static"
      ];
    };
  };
}
