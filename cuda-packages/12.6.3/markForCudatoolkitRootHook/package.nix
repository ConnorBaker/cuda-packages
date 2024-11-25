# Internal hook, used by cudatoolkit and cuda redist packages
# to accommodate automatic CUDAToolkit_ROOT construction
{
  backendStdenv,
  lib,
  makeSetupHook,
}:
makeSetupHook {
  name = "${backendStdenv.cudaNamePrefix}-mark-for-cudatoolkit-root-hook";

  meta = {
    description = "Setup hook which marks CUDA packages for inclusion in CUDA environment variables";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = lib.teams.cuda.members;
  };
} ./mark-for-cudatoolkit-root-hook.sh
