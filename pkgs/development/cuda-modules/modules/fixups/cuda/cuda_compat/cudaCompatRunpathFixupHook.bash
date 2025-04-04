# shellcheck shell=bash

# TODO(@connorbaker): Why this offset?
# Stubs are a used during linking, so we only want to run if we're in buildInputs.
if ((${hostOffset:?} != -1)); then
  nixInfoLog "skipping sourcing cudaCompatRunpathFixupHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"
  return 0
fi
nixLog "sourcing cudaCompatRunpathFixupHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"

# Declare the variable to avoid occursInArray throwing an error if it doesn't exist.
declare -ag prePhases

cudaCompatRunpathFixupHookPreRegistration() {
  # NOTE: Add to prePhases to ensure all setup hooks are sourced prior to running the order check.
  # NOTE: prePhases may not exist as an array.
  if occursInArray cudaCompatRunpathFixupHookPreRegistration prePhases; then
    nixLog "skipping cudaCompatRunpathFixupHookPreRegistration, already present in prePhases"
  else
    prePhases+=(cudaCompatRunpathFixupHookPreRegistration)
    nixLog "added cudaCompatRunpathFixupHookPreRegistration to prePhases"
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

  return 0
}

# NOTE: Does not double-add driverLib, which means it may move the priority up to the first occurrence of
# cudaCompatDir.
cudaCompatRunpathFixup() {
  local -r path="$1"
  # May be linked to compat libraries through `out/compat` or symlinks in `lib/lib`.
  local -r cudaCompatOutDir="@cudaCompatOutDir@"
  local -r cudaCompatLibDir="@cudaCompatLibDir@"
  local -r driverLibDir="@driverLibDir@"
  local -a originalRunpathEntries=()
  getRunpathEntries "$path" originalRunpathEntries

  nixErrorLog "@connorbaker: ensure correctness of cudaCompatRunpathFixup."

  # Canonicalize runpath entries, turning cudaCompatLibDir into cudaCompatOutDir.
  # Ensure that cudaCompatOutDir precedes driverLibDir in the runpath.

  # TODO(@connorbaker): Do we need to worry about cudaCudartRunpathFixupHook *moving* the position
  # of driverLibDir by way of replacing cudaStubLibDir with driverLibDir? That could cause it to leap-frog
  # over cudaCompatOutDir, which would be bad.

  local -a newRunpathEntries=()
  local -i driverLibDirSeen=0
  local -i cudaCompatOutDirSeen=0
  local runpathEntry
  for runpathEntry in "${originalRunpathEntries[@]}"; do
    # If runpathEntry is cudaCompatLibDir, replace it with cudaCompatOutDir.
    if [[ $runpathEntry == "$cudaCompatLibDir" ]]; then
      runpathEntry="$cudaCompatOutDir"
    fi

    # If we're looking at driverLibDir...
    if [[ $runpathEntry == "$driverLibDir" ]]; then
      # Early return if we've seen it before.
      ((driverLibDirSeen)) && continue

      # If we've not seen cudaCompatOutDir, add it to the runpath.
      if ! ((cudaCompatOutDirSeen)); then
        newRunpathEntries+=("$cudaCompatOutDir")
        # Mark it as seen.
        cudaCompatOutDirSeen=1
      fi

      # Mark driverLibDir as seen and continue.
      driverLibDirSeen=1
    fi

    # Add the entry to the new runpath.
    newRunpathEntries+=("$runpathEntry")
  done

  # TODO(@connorbaker): Do we need to add patchelf as a dependency?
  local -r originalRunpathString="$(concatStringsSep ":" originalRunpathEntries)"
  local -r newRunpathString="$(concatStringsSep ":" newRunpathEntries)"
  nixLog "replacing rpath of $path: $originalRunpathString -> $newRunpathString"
  patchelf --set-rpath "$newRunpathString" "$path"

  return 0
}
