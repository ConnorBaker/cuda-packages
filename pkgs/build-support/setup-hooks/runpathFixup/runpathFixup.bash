# shellcheck shell=bash

# symlinks are often created in postFixup
preDistHooks+=(runpathFixupHook)

# runpathFixup
# This function is used to fix up the runpath of a binary.
# Arguments:
#   1. An reference to a declared array containing the entries of the runpath.
#   2. An reference to a declared array that will be populated with the fixed runpath.
runpathFixup() {
  if (($# != 2)); then
    nixErrorLog "expected 2 arguments, got $#"
    nixErrorLog "usage: runpathFixup inputArrRef outputArrRef"
    return 1
  fi

  # shellcheck disable=SC2034
  local -rn inputArrayRef="$1"
  # shellcheck disable=SC2034
  local -rn outputArrayRef="$2"

  if ! isDeclaredArray "${!inputArrayRef}"; then
    nixErrorLog "first arugment inputArrayRef must be an array reference"
    return 1
  fi

  if ! isDeclaredArray "${!outputArrayRef}"; then
    nixErrorLog "second arugment outputArrayRef must be an array reference"
    return 1
  fi

  # Replace entries
  local -a postReplacedEntries=()
  if isDeclaredMap runpathFixupReplacements; then
    arrayReplace "${!inputArrayRef}" runpathFixupReplacements " " postReplacedEntries
  else
    # shellcheck disable=SC2034
    postReplacedEntries=("${inputArrayRef[@]}")
  fi

  # Remove empty entries
  # shellcheck disable=SC2034
  local -a emptyEntries=("")
  # shellcheck disable=SC2034
  local -a postNoEmptyEntries=()
  arrayDifference postReplacedEntries emptyEntries postNoEmptyEntries

  # Remove duplicates
  deduplicateArray postNoEmptyEntries "${!outputArrayRef}"
}

runpathFixupHook() {
  local -a elfFiles=()
  local -a originalEntries=()
  local -a entriesPre=()
  local -a entriesPost=()
  local output
  local file

  # shellcheck disable=SC2154
  for output in "${outputs[@]}"; do
    getElfFiles "$output" elfFiles
    for file in "${elfFiles[@]}"; do
      getRunpathEntries "$file" originalEntries
      entriesPost=("${originalEntries[@]}")

      while ! arraysAreEqual entriesPre entriesPost; do
        # shellcheck disable=SC2034
        entriesPre=("${entriesPost[@]}")
        runpathFixup entriesPre entriesPost
      done

      if ! arraysAreEqual originalEntries entriesPost; then
        nixLog "runpath of $file changed from ${originalEntries[*]} to ${entriesPost[*]}"
        patchelf --set-rpath "${entriesPost[*]}" "$file"
      fi
    done
  done
}
