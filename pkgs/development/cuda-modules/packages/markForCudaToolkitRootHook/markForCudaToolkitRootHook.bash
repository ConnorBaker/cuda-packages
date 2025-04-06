# shellcheck shell=bash

# TODO(@connorbaker): Why this offset?
if ((${hostOffset:?} != -1)); then
  nixInfoLog "skipping sourcing markForCudaToolkitRootHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"
  return 0
fi
nixLog "sourcing markForCudaToolkitRootHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"

markForCudaToolkitRootHookRegistration() {
  if occursInArray markForCudaToolkitRoot fixupOutputHooks; then
    nixLog "skipping markForCudaToolkitRoot, already present in fixupOutputHooks"
  else
    fixupOutputHooks+=(markForCudaToolkitRoot)
    nixLog "added markForCudaToolkitRoot to fixupOutputHooks"
  fi

  return 0
}

markForCudaToolkitRootHookRegistration

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
