{
  cudaPackagesConfig,
  lib,
}:
let
  inherit (cudaPackagesConfig) hasJetsonCudaCapability;
  inherit (lib.attrsets) recursiveUpdate;
  inherit (lib.lists) optionals;
in
prevAttrs: {
  allowFHSReferences = true;

  autoPatchelfIgnoreMissingDeps =
    prevAttrs.autoPatchelfIgnoreMissingDeps or [ ]
    ++ optionals hasJetsonCudaCapability [
      "libnvrm_gpu.so"
      "libnvrm_mem.so"
      "libnvdla_runtime.so"
    ];

  passthru = recursiveUpdate (prevAttrs.passthru or { }) {
    # `cuda_compat` only works on aarch64-linux, and only when building for Jetson devices.
    badPlatformsConditions = {
      "Trying to use cuda_compat on aarch64-linux targeting non-Jetson devices" =
        !hasJetsonCudaCapability;
    };
  };

  # NOTE: libraries are left in the `compat` directory by design: they require runtime driver libraries unavailable
  # to us inside the sandbox. Instead, linking against `libcuda.so` is handled by the stubs provided by `cuda_cudart`,
  # and the runtime path is set to our compatibility libraries by `cudaRunpathFixupHook`.
}
