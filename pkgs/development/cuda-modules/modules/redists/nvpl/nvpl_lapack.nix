{ nvpl_blas }:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    nvpl_blas
  ];
}
