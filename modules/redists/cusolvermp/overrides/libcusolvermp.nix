{
  cuda_cudart,
  cuda-lib,
  lib,
  libcal ? null,
  libcublas,
  libcusolver,
}:
prevAttrs: {
  badPlatformsConditions =
    prevAttrs.badPlatformsConditions
    // cuda-lib.utils.mkMissingPackagesBadPlatformsConditions {
      inherit libcal;
    };
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    cuda_cudart
    libcal
    libcublas
    libcusolver
  ];
}
