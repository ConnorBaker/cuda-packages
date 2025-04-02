{
  cudaLib,
  lib,
  libcal ? null,
  libcublas,
}:
let
  inherit (cudaLib.utils) mkMissingPackagesBadPlatformsConditions;
  inherit (lib.attrsets) recursiveUpdate;
in
prevAttrs: {
  # TODO: Looks like the minimum supported capability is 7.0 as of the latest:
  # https://docs.nvidia.com/cuda/cublasmp/getting_started/index.html
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    libcal
    libcublas
  ];

  passthru = recursiveUpdate (prevAttrs.passthru or { }) {
    badPlatformsConditions = mkMissingPackagesBadPlatformsConditions { inherit libcal; };
    brokenConditions = {
      # TODO(@connorbaker):
      "libcublasmp requires nvshmem which is not yet packaged" = true;
    };
  };
}
