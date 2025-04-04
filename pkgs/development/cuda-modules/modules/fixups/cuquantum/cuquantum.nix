{
  cuda_cudart,
  libcublas,
  libcusolver,
  libcutensor,
}:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    cuda_cudart
    libcublas
    libcusolver
    libcutensor
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
