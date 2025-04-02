{
  cuda_cudart,
  cudaLib,
  lib,
  libcal ? null,
  libcublas,
  libcusolver,
}:
let
  inherit (cudaLib.utils) mkMissingPackagesBadPlatformsConditions;
  inherit (lib.attrsets) recursiveUpdate;
in
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    cuda_cudart
    libcal
    libcublas
    libcusolver
  ];
  passthru = recursiveUpdate (prevAttrs.passthru or { }) {
    badPlatformsConditions = mkMissingPackagesBadPlatformsConditions { inherit libcal; };
  };
}
