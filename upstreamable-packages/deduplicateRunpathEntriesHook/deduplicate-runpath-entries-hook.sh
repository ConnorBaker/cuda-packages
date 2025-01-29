# shellcheck shell=bash

# Only run the hook from nativeBuildInputs
if ((${hostOffset:?} == -1 && ${targetOffset:?} == 0)); then
  # shellcheck disable=SC1091
  source @nixLogWithLevelAndFunctionNameHook@
  nixLog "sourcing deduplicate-runpath-entries-hook.sh"
else
  return 0
fi

if ((${deduplicateRunpathEntriesHookOnce:-0} > 0)); then
  nixWarnLog "skipping because the hook has been propagated more than once"
  return 0
fi

declare -ig deduplicateRunpathEntriesHookOnce=1
declare -ig dontDeduplicateRunpathEntries=${dontDeduplicateRunpathEntries:-0}

# NOTE: Add to prePhases to ensure all setup hooks are sourced prior to running the order check.
prePhases+=(deduplicateRunpathEntriesHookOrderCheckPhase)
nixLog "added deduplicateRunpathEntriesHookOrderCheckPhase to prePhases"

postFixupHooks+=("autoFixElfFiles deduplicateRunpathEntries")
nixLog "added 'autoFixElfFiles deduplicateRunpathEntries' to postFixupHooks"

# TODO: Need a way to add additional phases to the order check -- for example, CUDA hooks which modify the runpath
# must execute before this hook.
deduplicateRunpathEntriesHookOrderCheckPhase() {
  # Ensure that our setup hook runs after autoPatchelf.
  # NOTE: Brittle because it relies on the name of the hook not changing.
  local -r postFixupHooksString="${postFixupHooks[*]}"
  if [[ $postFixupHooksString == *"autoPatchelfPostFixup"* &&
    $postFixupHooksString != *"autoPatchelfPostFixup"*"autoFixElfFiles deduplicateRunpathEntries"* ]]; then
    nixErrorLog "autoPatchelfPostFixup must run before 'autoFixElfFiles deduplicateRunpathEntries'"
    exit 1
  fi
  return 0
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
  local originalRunpathString="$(patchelf --print-rpath "$path")"
  # Remove the trailing newline character.
  originalRunpathString="${originalRunpathString%$'\n'}"

  local -a originalRunpathEntries
  mapfile -d ":" -t originalRunpathEntries <<<"$originalRunpathString"

  # observedRunpathEntries is a map from runpath entry to the number of times it has been seen *in
  # originalRunpathEntries*.
  local -A observedRunpathEntries=()
  local -a newRunpathEntries=()
  local runpathEntry
  local -i runpathEntryTimesSeen
  local -i hasDuplicates=0
  for runpathEntry in "${originalRunpathEntries[@]}"; do
    runpathEntryTimesSeen=$((${observedRunpathEntries["$runpathEntry"]:-0} + 1))
    observedRunpathEntries["$runpathEntry"]=$runpathEntryTimesSeen

    if ((runpathEntryTimesSeen <= 1)); then
      newRunpathEntries+=("$runpathEntry")
    else
      hasDuplicates=1
    fi
  done

  if ((hasDuplicates > 0)); then
    nixErrorLog "found duplicate runpath entries in $path: $originalRunpathString"
    # NOTE: newRunpathEntries preserves the order of the entries and does not have duplicates, so we use it when
    # indexing into observedRunpathEntries.
    for runpathEntry in "${newRunpathEntries[@]}"; do
      runpathEntryTimesSeen=${observedRunpathEntries["$runpathEntry"]}
      if ((runpathEntryTimesSeen > 1)); then
        nixErrorLog "runpath entry $runpathEntry seen $runpathEntryTimesSeen times"
      fi
    done
  fi

  if ((dontDeduplicateRunpathEntries > 0)); then
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
