# shellcheck shell=bash

# Asserts that two arrays are equal, printing out differences if they are not.
# Does not short circuit on the first difference.
assertArraysAreEqual() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: assertArraysAreEqual expectedArrayRef actualArrayRef"
    exit 1
  fi

  local -nr expectedArrayRef="$1"
  local -nr actualArrayRef="$2"

  if [[ ! ${expectedArrayRef@a} =~ a ]]; then
    nixErrorLog "first arugment expectedArrayRef must be an array reference"
    exit 1
  fi

  if [[ ! ${actualArrayRef@a} =~ a ]]; then
    nixErrorLog "second arugment actualArrayRef must be an array reference"
    exit 1
  fi

  local -ir expectedArrayLength=${#expectedArrayRef[@]}
  local -ir actualArrayLength=${#actualArrayRef[@]}

  local -i hasDiff=0

  if ((expectedArrayLength != actualArrayLength)); then
    nixErrorLog "arrays differ in length: expectedArrayRef has length $expectedArrayLength but actualArrayRef has length $actualArrayLength"
    hasDiff=1
  fi

  local expectedValue
  local actualValue
  local -i idx=0
  for ((idx = 0; idx < expectedArrayLength || idx < actualArrayLength; idx++)); do
    expectedValue="${expectedArrayRef[idx]}"
    actualValue="${actualArrayRef[idx]}"

    if [[ $expectedValue != "$actualValue" ]]; then
      if ((idx >= expectedArrayLength)); then
        nixErrorLog "arrays differ at index $idx: expected value would be out of bounds but actual value is '$actualValue'"
      elif ((idx >= actualArrayLength)); then
        nixErrorLog "arrays differ at index $idx: expected value is '$expectedValue' but actual value would be out of bounds"
      else
        nixErrorLog "arrays differ at index $idx: expected value is '$expectedValue' but actual value is '$actualValue'"
      fi
      hasDiff=1
    fi
  done

  ((hasDiff)) && exit 1 || return 0
}
