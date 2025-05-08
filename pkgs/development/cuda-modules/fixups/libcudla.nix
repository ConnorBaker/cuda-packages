{ cudaStdenv, lib }:
prevAttrs: {
  autoPatchelfIgnoreMissingDeps =
    prevAttrs.autoPatchelfIgnoreMissingDeps or [ ]
    ++ lib.optionals cudaStdenv.hasJetsonCudaCapability [
      "libnvcudla.so"
    ];

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "dev"
        "include"
        "lib"
        "stubs"
      ];
    };
  };
}
