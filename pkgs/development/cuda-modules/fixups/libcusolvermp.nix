{
  cuda_cudart,
  cudaLib,
  libcal ? null,
  libcublas,
  libcusolver,
}:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    cuda_cudart
    libcal
    libcublas
    libcusolver
  ];

  passthru = prevAttrs.passthru or { } // {
    platformAssertions =
      prevAttrs.passthru.platformAssertions or [ ]
      ++ cudaLib.utils.mkMissingPackagesAssertions { inherit libcal; };

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
