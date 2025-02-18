# shellcheck shell=bash

# Only run the hook from nativeBuildInputs
# shellcheck disable=SC2154
if ((hostOffset == -1 && targetOffset == 0)); then
  nixLog "sourcing cuda-runpath-fixup-hook.sh"
else
  return 0
fi

if ((${cudaRunpathFixupHookOnce:-0})); then
  nixWarnLog "skipping because the hook has been propagated more than once"
  return 0
fi

declare -ig cudaRunpathFixupHookOnce=1
declare -ig dontCudaRunpathFixHookOrder=${dontCudaRunpathFixHookOrder:-0}

# NOTE: Add to prePhases to ensure all setup hooks are sourced prior to running the order check.
prePhases+=(cudaRunpathFixupHookOrderCheckPhase)
nixLog "added cudaRunpathFixupHookOrderCheckPhase to prePhases"

postFixupHooks+=("autoFixElfFiles cudaRunpathFixup")
nixLog "added 'autoFixElfFiles cudaRunpathFixup' to postFixupHooks"

cudaRunpathFixupHookOrderCheck() {
  # Ensure that our setup hook runs after autoPatchelf and autoAddDriverRunpath.
  # NOTE: This function because it relies on the name of the hooks not changing.
  if ! occursOnlyOrAfterInArray "autoFixElfFiles cudaRunpathFixup" autoPatchelfPostFixup postFixupHooks; then
    nixErrorLog "autoPatchelfPostFixup must run before 'autoFixElfFiles cudaRunpathFixup'"
    return 1
  elif ! occursOnlyOrAfterInArray "autoFixElfFiles cudaRunpathFixup" "autoFixElfFiles addDriverRunpath" postFixupHooks; then
    nixErrorLog "'autoFixElfFiles addDriverRunpath' must run before 'autoFixElfFiles cudaRunpathFixup'"
    return 1
  fi
  return 0
}

cudaRunpathFixHookOrder() {
  nixErrorLog "attempting to fix the hook order"
  local -a newPostFixupHooks=()
  # We know that:
  # 1. autoPatchelfPostFixup or 'autoFixElfFiles addDriverRunpath' is in postFixupHooks.
  # 2. 'autoFixElfFiles cudaRunpathFixup' is in postFixupHooks and occurs only once because we guard
  #     against it being added multiple times.
  # 3. autoPatchelfPostFixup or 'autoFixElfFiles addDriverRunpath' occurs before autoPatchelfPostFixup.
  # We just remove 'autoFixElfFiles cudaRunpathFixup' and add it back at the end.
  for hook in "${postFixupHooks[@]}"; do
    if [[ $hook == "autoFixElfFiles cudaRunpathFixup" ]]; then
      nixErrorLog "removing 'autoFixElfFiles cudaRunpathFixup'"
      continue
    fi

    nixErrorLog "keeping $hook"
    newPostFixupHooks+=("$hook")
  done
  nixErrorLog "adding 'autoFixElfFiles cudaRunpathFixup'"
  postFixupHooks=("${newPostFixupHooks[@]}" "autoFixElfFiles cudaRunpathFixup")

  # Run the check again to ensure the fix worked.
  if cudaRunpathFixupHookOrderCheck; then
    nixErrorLog "fixed the hook order; this is a workaround, please fix the hook order in the package definition!"
    return 0
  else
    nixErrorLog "failed to fix the hook order"
    exit 1
  fi
}

cudaRunpathFixupHookOrderCheckPhase() {
  if cudaRunpathFixupHookOrderCheck; then
    return 0
  elif ((dontCudaRunpathFixHookOrder)); then
    exit 1
  else
    cudaRunpathFixHookOrder && return 0
  fi
}

cudaRunpathFixup() {
  if (($# == 0)); then
    nixErrorLog "no path provided"
    exit 1
  elif (($# > 1)); then
    nixErrorLog "expected exactly one path"
    exit 1
  elif [[ -z ${1:-} ]]; then
    nixErrorLog "empty path"
    exit 1
  fi

  # The cudaCompatLibDir should appear before any other if not empty (that is, when it is available/desired).
  # TODO(@connorbaker): The cudaStubLibDir should be replaced with the driverLibDir (stubs are only for linking).
  local -r cudaCompatLibDir="@cudaCompatLibDir@"
  local -r cudaStubLibDir="@cudaStubLibDir@"
  local -r driverLibDir="@driverLibDir@"

  # TODO(@connorbaker): Unfortunately, this shares a lot of the implementation with the deduplicateRunpathEntries hook.

  local -r path="$1"

  # shellcheck disable=SC2155
  local -r originalRunpathString="$(patchelf --print-rpath "$path")"

  local -a originalRunpathEntries
  mapfile -d ":" -t originalRunpathEntries < <(echo -n "$originalRunpathString")

  # NOTE: These variables count the number of times a runpath entry exists *in newRunpathEntries*. As such, it is
  # either zero or one.
  # NOTE: cudaStubLibDirSeen is not present because it is always replaced with driverLibDir.
  local -i cudaCompatLibDirSeen=0
  local -i driverLibDirSeen=0

  local -a newRunpathEntries=()
  local runpathEntry
  for runpathEntry in "${originalRunpathEntries[@]}"; do
    # If runpathEntry is cudaStubLibDir, replace it with driverLibDir.
    if [[ $runpathEntry == "$cudaStubLibDir" ]]; then
      runpathEntry="$driverLibDir"
    fi

    # Case for driverLibDir.
    if [[ $runpathEntry == "$driverLibDir" ]]; then
      ((driverLibDirSeen)) && continue

      # If cudaCompatLibDir is set and we haven't seen it yet, add it to the runpath and mark it as seen.
      # NOTE: This ensures the compat library is loaded before the driver library!
      if [[ -n $cudaCompatLibDir && $cudaCompatLibDirSeen -lt 1 ]]; then
        newRunpathEntries+=("$cudaCompatLibDir")
        cudaCompatLibDirSeen=1
      fi

      # Now add driverLibDir to the runpath and mark it as seen.
      newRunpathEntries+=("$driverLibDir")
      driverLibDirSeen=1

    # Case for cudaCompatLibDir.
    elif [[ $runpathEntry == "$cudaCompatLibDir" ]]; then
      # If cudaCompatLibDir is set and we haven't seen it yet, add it to the runpath and mark it as seen.
      if [[ -n $cudaCompatLibDir && $cudaCompatLibDirSeen -lt 1 ]]; then
        newRunpathEntries+=("$cudaCompatLibDir")
        cudaCompatLibDirSeen=1
      fi

    # Case for any other entry -- just pass through, not our job to deduplicate.
    else
      newRunpathEntries+=("$runpathEntry")
    fi
  done

  local -r newRunpathString="$(concatStringsSep ":" newRunpathEntries)"
  if [[ $originalRunpathString != "$newRunpathString" ]]; then
    nixLog "replacing $originalRunpathString with $newRunpathString"
    patchelf --set-rpath "$newRunpathString" "$path"
  fi

  return 0
}
