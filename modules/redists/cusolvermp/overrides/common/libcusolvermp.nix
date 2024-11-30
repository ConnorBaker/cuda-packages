{
  cuda_cudart,
  lib,
  libcal ? null,
  libcublas,
  libcusolver,
}:
let
  inherit (lib.attrsets) recursiveUpdate;
  inherit (lib.cuda.utils) mkMissingPackagesBadPlatformsConditions;
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
