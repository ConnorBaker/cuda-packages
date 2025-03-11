# shellcheck shell=bash

fixupOutputHooks+=(markForCudaToolkitRoot)
nixLog "added markForCudaToolkitRoot to fixupOutputHooks"

markForCudaToolkitRoot() {
  nixDebugLog "creating ${prefix:?}/nix-support if it doesn't exist"
  mkdir -p "${prefix:?}/nix-support"
  local -r markerFile="include-in-cudatoolkit-root"
  local -r markerPath="$prefix/nix-support/$markerFile"

  # Return early if the file already exists.
  if [[ -f $markerPath ]]; then
    nixDebugLog "output ${output:?} already marked for inclusion by cudaHook"
    return 0
  fi

  nixLog "marking output ${output:?} for inclusion by cudaHook"
  touch "$markerPath"

  return 0
}
