# shellcheck shell=bash

# Only run the hook from nativeBuildInputs
if ((${hostOffset:?} == -1 && ${targetOffset:?} == 0)); then
  # shellcheck disable=SC1091
  source @nixLogWithLevelAndFunctionNameHook@
  nixLog "sourcing auto-add-cuda-compat-runpath.sh"
else
  return 0
fi

postFixupHooks+=("autoFixElfFiles addCudaCompatRunpath")
nixLog "added 'autoFixElfFiles addCudaCompatRunpath' to postFixupHooks"

# Patch all dynamically linked, ELF files with the CUDA driver (libcuda.so)
# coming from the cuda_compat package by adding it to the RUNPATH.
addCudaCompatRunpath() {
  if (($# == 0)); then
    nixErrorLog "no library path provided"
    exit 1
  elif (($# > 1)); then
    nixErrorLog "too many arguments"
    exit 1
  elif [[ -z ${1:-} ]]; then
    nixErrorLog "empty library path"
    exit 1
  fi

  local -r libPath="$1"
  local -r origRpath="$(patchelf --print-rpath "$libPath")"

  patchelf --set-rpath "@libcudaPath@:$origRpath" "$libPath"
}
