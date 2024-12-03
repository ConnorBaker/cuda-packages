{ nvpl_blas }:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs ++ [
    nvpl_blas
  ];
}
