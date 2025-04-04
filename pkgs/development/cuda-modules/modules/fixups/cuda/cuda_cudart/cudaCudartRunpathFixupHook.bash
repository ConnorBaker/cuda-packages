# shellcheck shell=bash

# TODO(@connorbaker): Why this offset?
# Stubs are a used during linking, so we only want to run if we're in buildInputs.
if ((${hostOffset:?} != 0)); then
  nixInfoLog "skipping sourcing cudaCudartRunpathFixupHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"
  return 0
fi
nixLog "sourcing cudaCudartRunpathFixupHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"

# Declare the variable to avoid occursInArray throwing an error if it doesn't exist.
declare -ag prePhases

cudaCudartRunpathFixupHookPreRegistration() {
  # NOTE: Add to prePhases to ensure all setup hooks are sourced prior to running the order check.
  # NOTE: prePhases may not exist as an array.
  if occursInArray cudaCudartRunpathFixupHookRegistration prePhases; then
    nixLog "skipping cudaCudartRunpathFixupHookRegistration, already present in prePhases"
  else
    prePhases+=(cudaCudartRunpathFixupHookRegistration)
    nixLog "added cudaCudartRunpathFixupHookRegistration to prePhases"
  fi

  return 0
}

cudaCudartRunpathFixupHookPreRegistration

# Registering during prePhases ensures that all setup hooks are sourced prior to installing ours,
# allowing us to always go after autoAddDriverRunpath and autoPatchelfHook.
cudaCudartRunpathFixupHookRegistration() {
  # NOTE: setup.sh uses recordPropagatedDependencies in fixupPhase, which overwrites dependency files, so we must run
  # in postFixup.
  if occursInArray "autoFixElfFiles cudaCudartRunpathFixup" postFixupHooks; then
    nixLog "skipping 'autoFixElfFiles cudaCudartRunpathFixup', already present in postFixupHooks"
  else
    postFixupHooks+=("autoFixElfFiles cudaCudartRunpathFixup")
    nixLog "added 'autoFixElfFiles cudaCudartRunpathFixup' to postFixupHooks"
  fi

  return 0
}

# NOTE: Does not double-add driverLib, which means it may move the priority up to the first occurrence of
# cudartStubLibDir.
cudaCudartRunpathFixup() {
  local -r path="$1"
  local -r cudartStubLibDir="@cudartStubLibDir@"
  local -r driverLibDir="@driverLibDir@"
  local -a originalRunpathEntries=()
  getRunpathEntries "$path" originalRunpathEntries

  if ! occursInArray "$cudartStubLibDir" originalRunpathEntries && ! occursInArray "$cudartStubLibDir/stubs" originalRunpathEntries; then
    nixInfoLog "skipping $path, no stubs output in runpath"
    return 0
  fi

  # Replace the runpath entries for the stubs with driverLibDir.
  local -a newRunpathEntries=()
  local -i driverLibDirSeen=0
  local runpathEntry
  for runpathEntry in "${originalRunpathEntries[@]}"; do
    # If runpathEntry is a stub dir, replace it with driverLibDir.
    if [[ $runpathEntry == "$cudartStubLibDir" || $runpathEntry == "$cudartStubLibDir/stubs" ]]; then
      runpathEntry="$driverLibDir"
    fi

    # If we're considering adding driverLibDir...
    if [[ $runpathEntry == "$driverLibDir" ]]; then
      # Early return if we've seen it before.
      ((driverLibDirSeen)) && continue
      # Otherwise mark it as seen and continue.
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
