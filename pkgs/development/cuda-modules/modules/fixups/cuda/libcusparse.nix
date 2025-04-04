{ libnvjitlink }:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [ libnvjitlink ];

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "dev"
        "include"
        "lib"
        "static"
        "stubs"
      ];
    };
  };
}
