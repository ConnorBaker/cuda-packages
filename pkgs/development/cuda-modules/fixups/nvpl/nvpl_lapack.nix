{ nvpl_blas }:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    nvpl_blas
  ];

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "dev"
        "include"
        "lib"
      ];
    };
  };
}
