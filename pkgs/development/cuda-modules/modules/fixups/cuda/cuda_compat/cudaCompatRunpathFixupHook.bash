# shellcheck shell=bash

# TODO(@connorbaker): Why this offset?
# Stubs are a used during linking, so we only want to run if we're in buildInputs.
if ((${hostOffset:?} != 0)); then
  nixInfoLog "skipping sourcing cudaCompatRunpathFixupHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"
  return 0
fi
nixLog "sourcing cudaCompatRunpathFixupHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"

# NOTE: This flag is duplicated in all CUDA setup hooks which modify ELF files to ensure consistency.
# patchelf defaults to using RUNPATH, so to preserve RPATH we need to be uniform.
declare -ig cudaForceRpath="@cudaForceRpath@"

# Declare the variable to avoid occursInArray throwing an error if it doesn't exist.
declare -ag prePhases

cudaCompatRunpathFixupHookPreRegistration() {
  # NOTE: Add to prePhases to ensure all setup hooks are sourced prior to running the order check.
  # NOTE: prePhases may not exist as an array.
  if occursInArray cudaCompatRunpathFixupHookRegistration prePhases; then
    nixLog "skipping cudaCompatRunpathFixupHookRegistration, already present in prePhases"
  else
    prePhases+=(cudaCompatRunpathFixupHookRegistration)
    nixLog "added cudaCompatRunpathFixupHookRegistration to prePhases"
  fi

  return 0
}

cudaCompatRunpathFixupHookPreRegistration

# Registering during prePhases ensures that all setup hooks are sourced prior to installing ours,
# allowing us to always go after autoAddDriverRunpath and autoPatchelfHook.
cudaCompatRunpathFixupHookRegistration() {
  # NOTE: setup.sh uses recordPropagatedDependencies in fixupPhase, which overwrites dependency files, so we must run
  # in postFixup.
  if occursInArray "autoFixElfFiles cudaCompatRunpathFixup" postFixupHooks; then
    nixLog "skipping 'autoFixElfFiles cudaCompatRunpathFixup', already present in postFixupHooks"
  else
    postFixupHooks+=("autoFixElfFiles cudaCompatRunpathFixup")
    nixLog "added 'autoFixElfFiles cudaCompatRunpathFixup' to postFixupHooks"
  fi

  # May be linked to compat libraries through `out/compat` or symlinks in `lib/lib`.
  # NOTE: Used in cudaCompatRunpathFixup.
  # shellcheck disable=SC2034
  declare -ag cudaCompatRunpathEntriesToRemove=(
    "@cudaCompatOutDir@"
    "@cudaCompatLibDir@"
    "@driverLibDir@"
  )

  return 0
}

cudaCompatRunpathFixup() {
  local -r path="$1"
  # NOTE: Used in getRunpathEntries.
  # shellcheck disable=SC2034
  local -a originalRunpathEntries=()
  getRunpathEntries "$path" originalRunpathEntries

  # Always prepend the runpath with cudaCompatOutDir to give it the highest priority.
  local -a newRunpathEntries=("@cudaCompatOutDir@")

  # Remove the entries that are in cudaCompatRunpathEntriesToRemove from the original runpath.
  # NOTE: This is safe because arrayDifference only mutates its third argument by appending.
  arrayDifference originalRunpathEntries cudaCompatRunpathEntriesToRemove newRunpathEntries

  # Add driverLibDir to the new runpath at the end, to ensure lowest priority.
  newRunpathEntries+=("@driverLibDir@")

  local -r originalRunpathString="$(concatStringsSep ":" originalRunpathEntries)"
  local -r newRunpathString="$(concatStringsSep ":" newRunpathEntries)"
  nixInfoLog "replacing rpath of $path: $originalRunpathString -> $newRunpathString"
  if ((cudaForceRpath)); then
    patchelf --remove-rpath "$path"
    patchelf --force-rpath --set-rpath "$newRunpathString" "$path"
  else
    patchelf --set-rpath "$newRunpathString" "$path"
  fi

  return 0
}
