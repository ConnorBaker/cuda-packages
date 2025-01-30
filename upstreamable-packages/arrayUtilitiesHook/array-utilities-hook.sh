# shellcheck shell=bash

# Only run the hook from nativeBuildInputs
if ((${hostOffset:?} == -1 && ${targetOffset:?} == 0)); then
  nixInfoLog "sourcing array-utilities-hook.sh"
else
  return 0
fi

if ((${arrayUtilitiesHookOnce:-0} > 0)); then
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

# Returns 0 if inputElem1 occurs before inputElem2 in inputArrRef, 1 otherwise.
elemIsBefore() {
  if (($# != 3)); then
    nixErrorLog "expected three arguments!"
    nixErrorLog "usage: elemIsBefore inputElem1 inputElem2 inputArrRef"
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
    case "$entry" in
    "$inputElem1") return 0 ;;
    "$inputElem2") return 1 ;;
    *) ;;
    esac
  done

  # Vacuously true if neither element is in the array.
  return 0
}

# Returns 0 if inputElem1 occurs after inputElem2 in inputArrRef, 1 otherwise.
elemIsAfter() {
  if (($# != 3)); then
    nixErrorLog "expected three arguments!"
    nixErrorLog "usage: elemIsAfter inputElem1 inputElem2 inputArrRef"
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
    nixLog "observed entry: $entry"
    case "$entry" in
    "$inputElem1")
      nixLog "observed inputElem1, returning 1"
      return 1
      ;;
    "$inputElem2")
      nixLog "observed inputElem2, returning 0"
      return 0
      ;;
    *) ;;
    esac
  done

  # Vacuously true if neither element is in the array.
  return 0
}

elemIsIn() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: elemIsIn inputElem inputArrRef"
    exit 1
  fi

  local -r inputElem="$1"
  local -rn inputArrRef="$2"

  if [[ ! ${inputArrRef@a} =~ a ]]; then
    nixErrorLog "second arugment inputArrRef must be an array reference"
    exit 1
  fi

  for entry in "${inputArrRef[@]}"; do
    if [[ $entry == "$inputElem" ]]; then
      return 0
    fi
  done

  return 1
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
    if [[ ${submapRef["$subMapKey"]} != "${supermapRef["$subMapKey"]}" ]]; then
      return 1
    fi
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

  mapfile -d '' -t outputArrRef < <(printf '%s\0' "${inputArrRef[@]}" | sort -z)
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
    numTimesSeen=$((${outputMapRef["$entry"]:-0} + 1))
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
    numTimesSeen=$((${outputMapRef["$entry"]:-0} + 1))
    outputMapRef["$entry"]=$numTimesSeen

    if ((numTimesSeen <= 1)); then
      outputArrRef+=("$entry")
    fi
  done

  return 0
}
