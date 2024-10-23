# Internal hook, used by cudatoolkit and cuda redist packages
# to accommodate automatic CUDAToolkit_ROOT construction
{ flags, makeSetupHook }:
makeSetupHook {
  name = "${flags.cudaNamePrefix}-mark-for-cudatoolkit-root-hook";
} ./mark-for-cudatoolkit-root-hook.sh
