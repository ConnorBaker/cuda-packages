{
  cuda-lib,
  lib,
  libcal ? null,
  libcublas,
}:
prevAttrs: {
  badPlatformsConditions =
    prevAttrs.badPlatformsConditions
    // cuda-lib.utils.mkMissingPackagesBadPlatformsConditions { inherit libcal; };
  # TODO: Looks like the minimum supported capability is 7.0 as of the latest:
  # https://docs.nvidia.com/cuda/cublasmp/getting_started/index.html
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    libcal
    libcublas
  ];
}
