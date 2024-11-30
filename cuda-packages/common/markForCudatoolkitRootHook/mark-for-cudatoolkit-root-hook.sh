# shellcheck shell=bash

# Only run the hook from nativeBuildInputs
if ((${hostOffset:?} == -1 && ${targetOffset:?} == 0)); then
  # shellcheck disable=SC1091
  source @nixLogWithLevelAndFunctionNameHook@
  nixLog "sourcing mark-for-cudatoolkit-root-hook.sh"
else
  return 0
fi

fixupOutputHooks+=(markForCUDAToolkit_ROOT)
nixLog "added markForCUDAToolkit_ROOT to fixupOutputHooks"

markForCUDAToolkit_ROOT() {
  nixDebugLog "creating ${prefix:?}/nix-support if it doesn't exist"
  mkdir -p "${prefix:?}/nix-support"
  local -r markerFile="include-in-cudatoolkit-root"
  local -r markerPath="$prefix/nix-support/$markerFile"

  # Return early if the file already exists.
  if [[ -f $markerPath ]]; then
    nixDebugLog "output ${output:?} already marked for inclusion by setupCudaHook"
    return 0
  fi

  nixLog "marking output ${output:?} for inclusion by setupCudaHook"
  touch "$markerPath"
}
