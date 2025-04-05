# shellcheck shell=bash

# TODO(@connorbaker): Why this offset?
# Stubs are a used during linking, so we only want to run if we're in buildInputs.
if ((${hostOffset:?} != 0)); then
  nixInfoLog "skipping sourcing cudaCudartRunpathFixupHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"
  return 0
fi
nixLog "sourcing cudaCudartRunpathFixupHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"

# NOTE: This flag is duplicated in all CUDA setup hooks which modify ELF files to ensure consistency.
# patchelf defaults to using RUNPATH, so to preserve RPATH we need to be uniform.
declare -ig dontCudaForceRpath=${dontCudaForceRpath:-0}

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

  # Replace the runpath entries for the stubs with driverLibDir.
  local -a newRunpathEntries=()
  local runpathEntry
  for runpathEntry in "${originalRunpathEntries[@]}"; do
    case "$runpathEntry" in
    "$cudartStubLibDir" | "$cudartStubLibDir/stubs" | "$driverLibDir") ;;
    *) newRunpathEntries+=("$runpathEntry") ;;
    esac
  done

  # Add driverLibDir to the new runpath at the end, to ensure lowest priority.
  newRunpathEntries+=("$driverLibDir")

  local -r originalRunpathString="$(concatStringsSep ":" originalRunpathEntries)"
  local -r newRunpathString="$(concatStringsSep ":" newRunpathEntries)"
  nixInfoLog "replacing rpath of $path: $originalRunpathString -> $newRunpathString"
  if ((dontCudaForceRpath)); then
    patchelf --set-rpath "$newRunpathString" "$path"
  else
    patchelf --remove-rpath "$path"
    patchelf --force-rpath --set-rpath "$newRunpathString" "$path"
  fi

  return 0
}
