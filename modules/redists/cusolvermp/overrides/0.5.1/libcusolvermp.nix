{
  cuda_cudart,
  lib,
  libcal ? null,
  libcublas,
  libcusolver,
}:
prevAttrs: {
  badPlatformsConditions =
    prevAttrs.badPlatformsConditions
    // lib.cuda.utils.mkMissingPackagesBadPlatformsConditions {
      inherit libcal;
    };
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    cuda_cudart
    libcal
    libcublas
    libcusolver
  ];
}
