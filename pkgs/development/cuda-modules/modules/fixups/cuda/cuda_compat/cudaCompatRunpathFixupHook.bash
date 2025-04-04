# shellcheck shell=bash

# TODO(@connorbaker): Why this offset?
# Stubs are a used during linking, so we only want to run if we're in buildInputs.
if ((${hostOffset:?} != 0)); then
  nixInfoLog "skipping sourcing cudaCompatRunpathFixupHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"
  return 0
fi
nixLog "sourcing cudaCompatRunpathFixupHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"

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

  local -a newRunpathEntries=(
    "$cudaCompatOutDir"
    "$driverLibDir"
  )
  local runpathEntry
  for runpathEntry in "${originalRunpathEntries[@]}"; do
    case "$runpathEntry" in
    # If runpathEntry is a stub dir, replace it with driverLibDir.
    "$cudaCompatOutDir" | "$cudaCompatLibDir" | "$driverLibDir")
      continue
      ;;
    *)
      # Add the entry to the new runpath.
      newRunpathEntries+=("$runpathEntry")
      ;;
    esac
  done

  local -r originalRunpathString="$(concatStringsSep ":" originalRunpathEntries)"
  local -r newRunpathString="$(concatStringsSep ":" newRunpathEntries)"
  nixInfoLog "replacing rpath of $path: $originalRunpathString -> $newRunpathString"
  patchelf --set-rpath "$newRunpathString" "$path"

  return 0
}
