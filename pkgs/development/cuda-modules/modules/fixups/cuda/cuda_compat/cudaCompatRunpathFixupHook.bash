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
declare -ig dontCudaForceRpath=${dontCudaForceRpath:-0}

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

cudaCompatRunpathFixup() {
  local -r path="$1"
  # May be linked to compat libraries through `out/compat` or symlinks in `lib/lib`.
  local -r cudaCompatOutDir="@cudaCompatOutDir@"
  local -r cudaCompatLibDir="@cudaCompatLibDir@"
  local -r driverLibDir="@driverLibDir@"
  local -a originalRunpathEntries=()
  getRunpathEntries "$path" originalRunpathEntries

  # Always prepend the runpath with cudaCompatOutDir to give it the highest priority.
  local -a newRunpathEntries=("$cudaCompatOutDir")
  local runpathEntry
  for runpathEntry in "${originalRunpathEntries[@]}"; do
    case "$runpathEntry" in
    "$cudaCompatOutDir" | "$cudaCompatLibDir" | "$driverLibDir") ;;
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
