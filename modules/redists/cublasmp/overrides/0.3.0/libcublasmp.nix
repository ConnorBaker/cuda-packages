{
  lib,
  libcal ? null,
  libcublas,
}:
prevAttrs: {
  badPlatformsConditions =
    prevAttrs.badPlatformsConditions
    // lib.cuda.utils.mkMissingPackagesBadPlatformsConditions { inherit libcal; };
  brokenConditions = prevAttrs.brokenConditions // {
    # TODO(@connorbaker):
    "libcublasmp requires nvshmem which is not yet packaged" = true;
  };
  # TODO: Looks like the minimum supported capability is 7.0 as of the latest:
  # https://docs.nvidia.com/cuda/cublasmp/getting_started/index.html
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    libcal
    libcublas
  ];
}
