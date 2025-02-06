# shellcheck shell=bash

# Only run the hook from nativeBuildInputs
# shellcheck disable=SC2154
if ((hostOffset == -1 && targetOffset == 0)); then
  nixLog "sourcing deduplicate-runpath-entries-hook.sh"
else
  return 0
fi

if ((${deduplicateRunpathEntriesHookOnce:-0})); then
  nixWarnLog "skipping because the hook has been propagated more than once"
  return 0
fi

declare -ig deduplicateRunpathEntriesHookOnce=1
declare -ig dontDeduplicateRunpathEntries=${dontDeduplicateRunpathEntries:-0}
declare -ig dontDeduplicateRunpathEntriesFixHookOrder=${dontDeduplicateRunpathEntriesFixHookOrder:-0}

# NOTE: Add to prePhases to ensure all setup hooks are sourced prior to running the order check.
prePhases+=(deduplicateRunpathEntriesHookOrderCheckPhase)
nixLog "added deduplicateRunpathEntriesHookOrderCheckPhase to prePhases"

postFixupHooks+=("autoFixElfFiles deduplicateRunpathEntries")
nixLog "added 'autoFixElfFiles deduplicateRunpathEntries' to postFixupHooks"

deduplicateRunpathEntriesHookOrderCheck() {
  # NOTE: Brittle because it relies on the name of the hook not changing.
  if ! occursOnlyOrAfterInArray "autoFixElfFiles deduplicateRunpathEntries" "autoFixElfFiles addDriverRunpath" postFixupHooks; then
    nixErrorLog "'autoFixElfFiles addDriverRunpath' must run before 'autoFixElfFiles deduplicateRunpathEntries'"
    return 1
  fi
  return 0
}

deduplicateRunpathEntriesFixHookOrder() {
  nixErrorLog "attempting to fix the hook order"
  local -a newPostFixupHooks=()
  # We know that:
  # 1. 'autoFixElfFiles addDriverRunpath' is in postFixupHooks.
  # 2. 'autoFixElfFiles deduplicateRunpathEntries' is in postFixupHooks and occurs only once because we guard
  #     against it being added multiple times.
  # 3. 'autoFixElfFiles deduplicateRunpathEntries' occurs before 'autoFixElfFiles addDriverRunpath'.
  # We assume that 'autoFixElfFiles addDriverRunpath' occurs only once.
  for hook in "${postFixupHooks[@]}"; do
    if [[ $hook == "autoFixElfFiles deduplicateRunpathEntries" ]]; then
      nixErrorLog "removing 'autoFixElfFiles deduplicateRunpathEntries'"
      continue
    fi

    nixErrorLog "keeping $hook"
    newPostFixupHooks+=("$hook")

    if [[ $hook == "autoFixElfFiles addDriverRunpath" ]]; then
      nixErrorLog "adding 'autoFixElfFiles deduplicateRunpathEntries'"
      newPostFixupHooks+=("autoFixElfFiles deduplicateRunpathEntries")
    fi
  done
  postFixupHooks=("${newPostFixupHooks[@]}")

  # Run the check again to ensure the fix worked.
  if deduplicateRunpathEntriesHookOrderCheck; then
    nixErrorLog "fixed the hook order; this is a workaround, please fix the hook order in the package definition!"
    return 0
  else
    nixErrorLog "failed to fix the hook order"
    exit 1
  fi
}

deduplicateRunpathEntriesHookOrderCheckPhase() {
  if deduplicateRunpathEntriesHookOrderCheck; then
    return 0
  elif ((dontDeduplicateRunpathEntriesFixHookOrder)); then
    exit 1
  else
    deduplicateRunpathEntriesFixHookOrder && return 0
  fi
}

deduplicateRunpathEntries() {
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

  local -r path="$1"

  # shellcheck disable=SC2155
  local -r originalRunpathString="$(patchelf --print-rpath "$path")"

  local -a originalRunpathEntries
  # shellcheck disable=SC2034
  # originalRunpathEntries is used.
  mapfile -d ':' -t originalRunpathEntries < <(echo -n "$originalRunpathString")

  # observedRunpathEntries is a map from runpath entry to the number of times it has been seen *in
  # originalRunpathEntries*.
  local -A observedRunpathEntries=()
  local -a newRunpathEntries=()

  deduplicateArray originalRunpathEntries newRunpathEntries observedRunpathEntries

  # TODO: Should this be info-level and above?
  if ((${#newRunpathEntries[@]} < ${#originalRunpathEntries[@]})); then
    nixErrorLog "found duplicate runpath entries in $path: $originalRunpathString"
    for runpathEntry in "${newRunpathEntries[@]}"; do
      runpathEntryTimesSeen=${observedRunpathEntries["$runpathEntry"]}
      if ((runpathEntryTimesSeen > 1)); then
        nixErrorLog "runpath entry $runpathEntry seen $runpathEntryTimesSeen times"
      fi
    done
  fi

  if ((dontDeduplicateRunpathEntries)); then
    nixLog "skipping deduplication because dontDeduplicateRunpathEntries is set"
    return 0
  fi

  local -r newRunpathString="$(concatStringsSep ":" newRunpathEntries)"
  if [[ $originalRunpathString != "$newRunpathString" ]]; then
    nixLog "replacing $originalRunpathString with $newRunpathString"
    patchelf --set-rpath "$newRunpathString" "$path"
  fi

  return 0
}
