# Internal hook, used by cudatoolkit and cuda redist packages
# to accommodate automatic CUDAToolkit_ROOT construction
{
  config,
  lib,
  makeSetupHook,
}:
let
  finalAttrs = {
    # NOTE: Does not depend on the CUDA package set, so do not use cudaNamePrefix to avoid causing
    # unnecessary / duplicate store paths.
    name = "markForCudaToolkitRootHook";

    meta = {
      description = "Setup hook which marks CUDA packages for inclusion in CUDA environment variables";
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
makeSetupHook finalAttrs ./markForCudaToolkitRootHook.bash
