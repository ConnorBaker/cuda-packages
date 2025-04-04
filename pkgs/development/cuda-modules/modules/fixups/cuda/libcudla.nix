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
