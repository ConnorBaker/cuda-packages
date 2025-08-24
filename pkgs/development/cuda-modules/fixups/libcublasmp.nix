{
  _cuda,
  libcal ? null,
  libcublas,
  nvshmem ? null, # TODO(@connorbaker): package this
}:
prevAttrs: {
  # TODO: Looks like the minimum supported capability is 7.0 as of the latest:
  # https://docs.nvidia.com/cuda/cublasmp/getting_started/index.html
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    libcal
    libcublas
  ];

  passthru = prevAttrs.passthru or { } // {
    platformAssertions =
      prevAttrs.passthru.platformAssertions or [ ]
      ++ _cuda.lib._mkMissingPackagesAssertions { inherit libcal nvshmem; };

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
