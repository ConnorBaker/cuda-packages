{
  cudaLib,
  libcal ? null,
  libcublas,
}:
prevAttrs: {
  # TODO: Looks like the minimum supported capability is 7.0 as of the latest:
  # https://docs.nvidia.com/cuda/cublasmp/getting_started/index.html
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    libcal
    libcublas
  ];

  passthru = prevAttrs.passthru or { } // {
    badPlatformsConditions =
      prevAttrs.passthru.badPlatformsConditions or { }
      // cudaLib.utils.mkMissingPackagesBadPlatformsConditions { inherit libcal; };

    brokenConditions = prevAttrs.passthru.brokenConditions or { } // {
      # TODO(@connorbaker):
      "libcublasmp requires nvshmem which is not yet packaged" = true;
    };

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
