# shellcheck shell=bash

# TODO(@connorbaker): Why this offset?
if [[ -n ${strictDeps:-} && ${hostOffset:-0} -ne -1 ]]; then
  nixInfoLog "skipping sourcing markForCudaToolkitRootHook.bash (hostOffset=${hostOffset:-0}) (targetOffset=${targetOffset:-0})"
  return 0
fi
nixLog "sourcing markForCudaToolkitRootHook.bash (hostOffset=${hostOffset:-0}) (targetOffset=${targetOffset:-0})"

# Declare the variable to avoid occursInArray throwing an error if it doesn't exist.
declare -ag prePhases

# NOTE: Add to prePhases to ensure all setup hooks are sourced prior to running the order check.
# TODO(@connorbaker): Due to the order Nixpkgs setup sources files, dependencies are not sourced
# prior to the current node. As such, even though we have occursInArray as one of our propagated
# build inputs, we cannot use it at the time the hook is sourced.
# See: https://github.com/NixOS/nixpkgs/pull/31414
prePhases+=(markForCudaToolkitRootHookRegistration)
nixLog "added markForCudaToolkitRootHookRegistration to prePhases"

markForCudaToolkitRootHookRegistration() {
  if occursInArray markForCudaToolkitRoot fixupOutputHooks; then
    nixLog "skipping markForCudaToolkitRoot, already present in fixupOutputHooks"
  else
    fixupOutputHooks+=(markForCudaToolkitRoot)
    nixLog "added markForCudaToolkitRoot to fixupOutputHooks"
  fi

  return 0
}

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
