{
  cuda_cudart ? null,
  cuda-lib,
  lib,
  libcal ? null,
  libcublas ? null,
  libcusolver ? null,
}:
prevAttrs: {
  badPlatformsConditions =
    prevAttrs.badPlatformsConditions
    // cuda-lib.utils.mkMissingPackagesBadPlatformsConditions {
      inherit
        cuda_cudart
        libcal
        libcublas
        libcusolver
        ;
    };
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    libcal
    libcublas
    libcusolver
    cuda_cudart
  ];
}
