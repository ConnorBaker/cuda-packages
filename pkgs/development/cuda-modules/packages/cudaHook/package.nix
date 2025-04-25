# Currently propagated by cuda_nvcc or cudatoolkit, rather than used directly
{
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
      maintainers = lib.teams.cuda.members;
    };
  };
in
makeSetupHook finalAttrs ./cudaHook.bash
