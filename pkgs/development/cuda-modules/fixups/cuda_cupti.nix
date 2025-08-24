{ backendStdenv, lib }:
prevAttrs: {
  allowFHSReferences = true;

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "dev"
        "include"
        "lib"
        "samples"
      ]
      ++ lib.optionals (backendStdenv.hostNixSystem == "x86_64-linux") [ "static" ];
    };
  };
}
