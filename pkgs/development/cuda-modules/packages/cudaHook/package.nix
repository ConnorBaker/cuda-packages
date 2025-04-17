# Currently propagated by cuda_nvcc or cudatoolkit, rather than used directly
{
  config,
  lib,
  makeSetupHook,
}:
let
  finalAttrs = {
    # NOTE: Does not depend on the CUDA package set, so do not use cudaNamePrefix to avoid causing
    # unnecessary / duplicate store paths.
    name = "cudaHook";

    substitutions.cudaHook = placeholder "out";

    meta = {
      description = "Setup hook for CUDA packages";
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      broken =
        lib.warnIfNot config.cudaSupport
          "CUDA support is disabled and you are building a CUDA package (${finalAttrs.name}); expect breakage!"
          false;
      maintainers = lib.teams.cuda.members;
    };
  };
in
makeSetupHook finalAttrs ./cudaHook.bash
