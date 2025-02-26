# shellcheck shell=bash

@functionGuard@

# arrayReplace
# Replaces all occurrences of each key of inputMapRef in inputArrRef with the values provided by the delimted string in
# the corresponding value of inputMapRef.
# Arguments:
# - inputArrRef: a reference to an array (not mutated)
# - inputMapRef: a reference to an associative array (not mutated)
# - delimiter: a character used to delimit the values in inputMapRef
# - outputArrRef: a reference to an array (mutated)
arrayReplace() {
  if (($# != 4)); then
    nixErrorLog "expected four arguments!"
    nixErrorLog "usage: arrayReplace inputArrRef inputMapRef delimiter outputArrRef"
    exit 1
  fi

  local -rn inputArrRef="$1"
  local -rn inputMapRef="$2"
  local -r delimiter="$3"
  # shellcheck disable=SC2178
  local -rn outputArrRef="$4"

  if ! isDeclaredArray "${!inputArrRef}"; then
    nixErrorLog "first arugment inputArrRef must be an array reference"
    exit 1
  fi

  if ! isDeclaredMap "${!inputMapRef}"; then
    nixErrorLog "second arugment inputMapRef must be an associative array reference"
    exit 1
  fi

  if ! isDeclaredArray "${!outputArrRef}"; then
    nixErrorLog "third arugment outputArrRef must be an array reference"
    exit 1
  fi

  # Early return for empty array and replacement map.
  if ((${#inputArrRef[@]} == 0)); then
    outputArrRef=()
    return 0
  elif ((${#inputMapRef[@]} == 0)); then
    outputArrRef=("${inputArrRef[@]}")
    return 0
  fi

  local elem
  local replacementString
  local -a replacementElemArray=()
  for elem in "${inputArrRef[@]}"; do
    # NOTE: We must use the slow check for key presence because we need to be able to discern between the key being
    # absent and the key being present with an empty string as the value.
    if occursInMapKeys "$elem" "${!inputMapRef}"; then
      replacementString="${inputMapRef["$elem"]}"
      replacementElemArray=()
      if [[ -n $replacementString ]]; then
        mapfile -d "$delimiter" -t replacementElemArray < <(echo -n "$replacementString")
      fi
      outputArrRef+=("${replacementElemArray[@]}")
    else
      outputArrRef+=("$elem")
    fi
  done

  return 0
}
