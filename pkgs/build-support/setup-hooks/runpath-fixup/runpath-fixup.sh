# shellcheck shell=bash

# Only run the hook from nativeBuildInputs
# shellcheck disable=SC2154
if ((hostOffset == -1 && targetOffset == 0)); then
  nixInfoLog "sourcing runpath-fixup.sh"
else
  return 0
fi

if ((${runpathFixupHookOnce:-0})); then
  nixInfoLog "skipping because the hook has been propagated more than once"
  return 0
fi

declare -ig runpathFixupHookOnce=1

# symlinks are often created in postFixup
preDistHooks+=(runpathFixupHook)

# getElfFilesInOutputs
# Returns a list of ELF files in the outputs of the provided derivation.
getElfFilesInOutputs() {
  if (($# != 1)); then
    nixErrorLog "expected one argument!"
    nixErrorLog "usage: getElfFilesInOutputs outputArrRef"
    exit 1
  fi

  # shellcheck disable=SC2178
  local -rn outputArrRef="$1"

  if ! isDeclaredArray "${!outputArrRef}"; then
    nixErrorLog "first arugment outputArrRef must be an array reference"
    exit 1
  fi

  # NOTE: `-type f` should prevent inclusion of directories or symlinks.
  local file
  while IFS= read -r -d $'\0' file; do
    if ! isELF "$file"; then
      nixLog "excluding $file because it's not an ELF file"
      continue
    fi

    # NOTE: Since the input is sorted, the output is sorted by virtue of us iterating over it in order.
    nixLog "including $file"
    outputArrRef+=("$file")

    # NOTE from sort manpage: The locale specified by the environment affects sort order. Set LC_ALL=C to get the
    # traditional sort order that uses native byte values.
  done < <(find "${outputs[@]}" -type f -print0 | LC_ALL=C sort --stable --zero-terminated)

  return 0
}

getRunpathEntries() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: getRunpathEntries path outputArrRef"
    exit 1
  fi

  local -r path="$1"
  # shellcheck disable=SC2178
  local -rn outputArrRef="$2"

  if ! isDeclaredArray "${!outputArrRef}"; then
    nixErrorLog "second arugment outputArrRef must be an array reference"
    exit 1
  fi

  local -r runpath="$(patchelf --print-rpath "$path")"

  if [[ -z $runpath ]]; then
    outputArrRef=()
    return 0
  fi

  mapfile -d ':' -t outputArrRef < <(echo -n "$runpath")
  return 0
}

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

  if ! isDeclaredArray inputArrayRef; then
    nixErrorLog "first arugment inputArrayRef must be an array reference"
    return 1
  fi

  if ! isDeclaredArray outputArrayRef; then
    nixErrorLog "second arugment outputArrayRef must be an array reference"
    return 1
  fi

  # Replace entries
  local -a postReplacedEntries=()
  if isDeclaredMap runpathFixupReplacements; then
    arrayReplace inputArrayRef runpathFixupReplacements " " postReplacedEntries
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
  deduplicateArray postNoEmptyEntries outputArrayRef
}

runpathFixupHook() {
  local -a elfFiles=()
  getElfFilesInOutputs elfFiles

  local file
  local -a originalEntries=()
  local -a entriesPre=()
  local -a entriesPost=()
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
}
