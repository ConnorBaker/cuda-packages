{ cudaConfig, lib }:
prevAttrs: {
  allowFHSReferences = true;

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "dev"
        "include"
        "lib"
        "static"
      ] ++ lib.optionals (cudaConfig.hostNixSystem == "x86_64-linux") [ "static" ];
    };
  };
}
