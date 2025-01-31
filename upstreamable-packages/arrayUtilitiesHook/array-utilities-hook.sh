# shellcheck shell=bash

# Only run the hook from nativeBuildInputs
# shellcheck disable=SC2154
if ((hostOffset == -1 && targetOffset == 0)); then
  nixInfoLog "sourcing array-utilities-hook.sh"
else
  return 0
fi

if ((${arrayUtilitiesHookOnce:-0})); then
  nixInfoLog "skipping because the hook has been propagated more than once"
  return 0
fi

declare -ig arrayUtilitiesHookOnce=1

# TODO: Will empty arrays be considered unset and have no type?
arraysAreEqual() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: arraysAreEqual inputArr1Ref inputArr2Ref"
    exit 1
  fi

  local -rn inputArr1Ref="$1"
  local -rn inputArr2Ref="$2"

  if [[ ! ${inputArr1Ref@a} =~ a ]]; then
    nixErrorLog "first arugment inputArr1Ref must be an array reference"
    exit 1
  fi

  if [[ ! ${inputArr2Ref@a} =~ a ]]; then
    nixErrorLog "second arugment inputArr2Ref must be an array reference"
    exit 1
  fi

  if [[ ${#inputArr1Ref[@]} -ne ${#inputArr2Ref[@]} || ${inputArr1Ref[*]@K} != "${inputArr2Ref[*]@K}" ]]; then
    return 1
  fi

  return 0
}

# Returns 0 if inputElem1 occurs before inputElem2 in inputArrRef or if inputElem1 occurs and inputElem2 does not.
# Returns 1 otherwise.
occursOnlyOrBeforeInArray() {
  if (($# != 3)); then
    nixErrorLog "expected three arguments!"
    nixErrorLog "usage: occursOnlyOrBeforeInArray inputElem1 inputElem2 inputArrRef"
    exit 1
  fi

  local -r inputElem1="$1"
  local -r inputElem2="$2"
  local -rn inputArrRef="$3"

  if [[ ! ${inputArrRef@a} =~ a ]]; then
    nixErrorLog "third arugment inputArrRef must be an array reference"
    exit 1
  fi

  if [[ $inputElem1 == "$inputElem2" ]]; then
    nixErrorLog "inputElem1 and inputElem2 must be different"
    exit 1
  fi

  for entry in "${inputArrRef[@]}"; do
    # Early return on finding inputElem1
    [[ $entry == "$inputElem1" ]] && return 0
    # Stop searching if we find inputElem2
    [[ $entry == "$inputElem2" ]] && break
  done

  return 1
}

# Returns 0 if inputElem1 occurs after inputElem2 in inputArrRef or if inputElem1 occurs and inputElem2 does not.
# Returns 1 otherwise.
occursOnlyOrAfterInArray() {
  if (($# != 3)); then
    nixErrorLog "expected three arguments!"
    nixErrorLog "usage: occursOnlyOrAfterInArray inputElem1 inputElem2 inputArrRef"
    exit 1
  fi

  local -r inputElem1="$1"
  local -r inputElem2="$2"
  local -rn inputArrRef="$3"

  if [[ ! ${inputArrRef@a} =~ a ]]; then
    nixErrorLog "third arugment inputArrRef must be an array reference"
    exit 1
  fi

  if [[ $inputElem1 == "$inputElem2" ]]; then
    nixErrorLog "inputElem1 and inputElem2 must be different"
    exit 1
  fi

  local -i seenInputElem1=0
  local -i seenInputElem2=0
  for entry in "${inputArrRef[@]}"; do
    if [[ $entry == "$inputElem1" ]]; then
      # If we've already seen inputElem2, then inputElem1 occurs after inputElem2 and we can return success.
      ((seenInputElem2)) && return 0
      # Otherwise, we've seen inputElem1 and are waiting to see if inputElem2 occurs.
      seenInputElem1=1
    elif [[ $entry == "$inputElem2" ]]; then
      # Since we've seen inputElem2, we can return failure if we've already seen inputElem1.
      ((seenInputElem1)) && return 1
      # Otherwise, we've seen inputElem2 and are waiting to see if inputElem1 occurs.
      seenInputElem2=1
    fi
  done

  # Due to the structure of the return statements, when we exit the for loop, we know that at most one of the
  # input elements has been seen.
  # If we've seen inputElem1, then we know that inputElem2 didn't occur, so we return success.
  # If we haven't seen inputElem1, it doesn't matter if we've seen inputElem2 or not -- we return failure.
  return $((1 - seenInputElem1))
}

# Returns 0 if inputElem occurs in inputArrRef, 1 otherwise.
occursInArray() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: occursInArray inputElem inputArrRef"
    exit 1
  fi

  local -r inputElem="$1"
  local -rn inputArrRef="$2"

  if [[ ! ${inputArrRef@a} =~ a ]]; then
    nixErrorLog "second arugment inputArrRef must be an array reference"
    exit 1
  fi

  for entry in "${inputArrRef[@]}"; do
    [[ $entry == "$inputElem" ]] && return 0
  done

  return 1
}

# TODO: Would it be a mistake to provided an occursInSortedArray?

# Sorts inputArrRef and stores the result in outputArrRef.
sortArray() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: sortArray inputArrRef outputArrRef"
    exit 1
  fi

  local -rn inputArrRef="$1"
  local -rn outputArrRef="$2"

  if [[ ! ${inputArrRef@a} =~ a ]]; then
    nixErrorLog "first arugment inputArrRef must be an array reference"
    exit 1
  fi

  if [[ ! ${outputArrRef@a} =~ a ]]; then
    nixErrorLog "second arugment outputArrRef must be an array reference"
    exit 1
  fi

  # NOTE from sort manpage: The locale specified by the environment affects sort order. Set LC_ALL=C to get the
  # traditional sort order that uses native byte values.
  mapfile -d '' -t outputArrRef < <(printf '%s\0' "${inputArrRef[@]}" | LC_ALL=C sort --stable --zero-terminated)
  return 0
}

# Returns a sorted array of the keys of inputMapRef.
getMapKeys() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: getMapKeys inputMapRef outputArrRef"
    exit 1
  fi

  local -rn inputMapRef="$1"
  # shellcheck disable=SC2178
  # Don't warn about outputArrRef being used as an array because it is an array.
  local -rn outputArrRef="$2"

  if [[ ! ${inputMapRef@a} =~ A ]]; then
    nixErrorLog "first arugment inputMapRef must be an associative array reference"
    exit 1
  fi

  if [[ ! ${outputArrRef@a} =~ a ]]; then
    nixErrorLog "second arugment outputArrRef must be an array reference"
    exit 1
  fi

  # TODO: Should we hide mutation from the caller?
  outputArrRef=("${!inputMapRef[@]}")
  sortArray outputArrRef outputArrRef
  return 0
}

# Returns 0 if inputElem occurs in the keys of inputMapRef, 1 otherwise.
occursInMapKeys() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: occursInMapKeys inputElem inputMapRef"
    exit 1
  fi

  local -r inputElem="$1"
  local -rn inputMapRef="$2"

  if [[ ! ${inputMapRef@a} =~ A ]]; then
    nixErrorLog "second arugment inputMapRef must be an associative array reference"
    exit 1
  fi

  # shellcheck disable=SC2034
  # keys is used in getMapKeys
  local -a keys
  getMapKeys inputMapRef keys
  occursInArray "$inputElem" keys
  return $? # Return the result of occursInArray
}

# TODO: Will empty arrays be considered unset and have no type?
mapIsSubmap() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: mapIsSubmap submapRef supermapRef"
    exit 1
  fi

  local -rn submapRef="$1"
  local -rn supermapRef="$2"

  if [[ ! ${submapRef@a} =~ A ]]; then
    nixErrorLog "first arugment submapRef must be an associative array reference"
    exit 1
  fi

  if [[ ! ${supermapRef@a} =~ A ]]; then
    nixErrorLog "second arugment supermapRef must be an associative array reference"
    exit 1
  fi

  local subMapKey
  for subMapKey in "${!submapRef[@]}"; do
    [[ ${submapRef["$subMapKey"]} != "${supermapRef["$subMapKey"]}" ]] && return 1
  done

  return 0
}

# TODO: Will empty arrays be considered unset and have no type?
mapsAreEqual() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: mapsAreEqual inputMap1Ref inputMap2Ref"
    exit 1
  fi

  local -rn inputMap1Ref="$1"
  local -rn inputMap2Ref="$2"

  if [[ ! ${inputMap1Ref@a} =~ A ]]; then
    nixErrorLog "first arugment inputMap1Ref must be an associative array reference"
    exit 1
  fi

  if [[ ! ${inputMap2Ref@a} =~ A ]]; then
    nixErrorLog "second arugment inputMap2Ref must be an associative array reference"
    exit 1
  fi

  if ((${#inputArr1Ref[@]} != ${#inputArr2Ref[@]})) ||
    ! mapIsSubmap inputMap1Ref inputMap2Ref ||
    ! mapIsSubmap inputMap2Ref inputMap1Ref; then
    return 1
  fi

  return 0
}

# computeFrequencyMap
# Produces a frequency map of the elements in an array.
#
# Arguments:
# - inputArrRef: a reference to an array (not mutated)
# - outputMapRef: a reference to an associative array (mutated)
#
# Returns 0.
computeFrequencyMap() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: computeFrequencyMap inputArrRef outputMapRef"
    exit 1
  fi

  local -rn inputArrRef="$1"
  local -rn outputMapRef="$2"

  if [[ ! ${inputArrRef@a} =~ a ]]; then
    nixErrorLog "first arugment inputArrRef must be an array reference"
    exit 1
  fi

  if [[ ! ${outputMapRef@a} =~ A ]]; then
    nixErrorLog "second arugment outputMapRef must be an associative array reference"
    exit 1
  fi

  local -i numTimesSeen
  for entry in "${inputArrRef[@]}"; do
    # NOTE: Unset values inside arithmetic expressions default to zero.
    numTimesSeen=$((${outputMapRef["$entry"]} + 1))
    outputMapRef["$entry"]=$numTimesSeen
  done

  return 0
}

# deduplicateArray
# Deduplicates an array. If outputMapRef is provided, it will contain the frequency of each element in the input array.
#
# Arguments:
# - inputArrRef: a reference to an array (not mutated)
# - outputArrRef: a reference to an array (mutated)
# - outputMapRef: a reference to an associative array (mutated, optional)
#
# Returns 0.
deduplicateArray() {
  if (($# != 2 && $# != 3)); then
    nixErrorLog "expected two or three arguments!"
    nixErrorLog "usage: deduplicateArray inputArrRef outputArrRef [outputMapRef]"
    exit 1
  fi

  local -rn inputArrRef="$1"
  # shellcheck disable=SC2178
  # don't warn about outputArrRef being used as an array because it is an array.
  local -rn outputArrRef="$2"
  # shellcheck disable=SC2034
  # outputMap is used in outputMapRef
  local -A outputMap
  # shellcheck disable=SC2178
  # don't warn about outputMapRef being used as an array because it is an array.
  local -rn outputMapRef="${3:-outputMap}"

  if [[ ! ${inputArrRef@a} =~ a ]]; then
    nixErrorLog "first arugment inputArrRef must be an array reference"
    exit 1
  fi

  if [[ ! ${outputArrRef@a} =~ a ]]; then
    nixErrorLog "second arugment outputArrRef must be an array reference"
    exit 1
  fi

  if [[ ! ${outputMapRef@a} =~ A ]]; then
    nixErrorLog "third arugment outputMapRef must be an associative array reference when present"
    exit 1
  fi

  local -i numTimesSeen
  for entry in "${inputArrRef[@]}"; do
    # NOTE: Unset values inside arithmetic expressions default to zero.
    numTimesSeen=$((${outputMapRef["$entry"]} + 1))
    outputMapRef["$entry"]=$numTimesSeen

    if ((numTimesSeen <= 1)); then
      outputArrRef+=("$entry")
    fi
  done

  return 0
}
