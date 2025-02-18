# shellcheck shell=bash

# Asserts that two maps are equal, printing out differences if they are not.
# Does not short circuit on the first difference.
assertMapsAreEqual() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: assertMapsAreEqual expectedMapRef actualMapRef"
    exit 1
  fi

  local -nr expectedMapRef="$1"
  local -nr actualMapRef="$2"

  if [[ ! ${expectedMapRef@a} =~ A ]]; then
    nixErrorLog "first arugment expectedMapRef must be an associative array reference"
    exit 1
  fi

  if [[ ! ${actualMapRef@a} =~ A ]]; then
    nixErrorLog "second arugment actualMapRef must be an associative array reference"
    exit 1
  fi

  # NOTE from sort manpage: The locale specified by the environment affects sort order. Set LC_ALL=C to get the
  # traditional sort order that uses native byte values.

  local -a sortedExpectedKeys
  mapfile -d '' -t sortedExpectedKeys < <(printf '%s\0' "${!expectedMapRef[@]}" | LC_ALL=C sort --stable --zero-terminated)

  local -a sortedActualKeys
  mapfile -d '' -t sortedActualKeys < <(printf '%s\0' "${!actualMapRef[@]}" | LC_ALL=C sort --stable --zero-terminated)

  local -ir expectedLength=${#expectedMapRef[@]}
  local -ir actualLength=${#actualMapRef[@]}

  local -i hasDiff=0

  if ((expectedLength != actualLength)); then
    nixErrorLog "maps differ in number of keys: expectedMap has length $expectedLength but actualMap has length $actualLength"
    hasDiff=1
  fi

  local -i expectedKeyIdx=0
  local expectedKey
  local expectedValue
  local -i actualKeyIdx=0
  local actualKey
  local actualValue
  while ((expectedKeyIdx < expectedLength || actualKeyIdx < actualLength)); do
    expectedKey="${sortedExpectedKeys[$expectedKeyIdx]}"
    actualKey="${sortedActualKeys[$actualKeyIdx]}"

    if [[ $expectedKey < $actualKey ]]; then
      actualValue="${actualMapRef["$actualKey"]}"
      nixErrorLog "actualMap has key '$actualKey' with value '$actualValue' but expectedMap has no such key"
      hasDiff=1
      actualKeyIdx+=1
    elif [[ $expectedKey == "$actualKey" ]]; then
      expectedValue="${expectedMapRef["$expectedKey"]}"
      actualValue="${actualMapRef["$actualKey"]}"

      if [[ $expectedValue != "$actualValue" ]]; then
        nixErrorLog "maps differ at key '$expectedKey': expectedMap value is '$expectedValue' but actualMap value is '$actualValue'"
        hasDiff=1
      fi

      expectedKeyIdx+=1
      actualKeyIdx+=1
    else
      expectedValue="${expectedMapRef["$expectedKey"]}"
      nixErrorLog "expectedMap has key '$expectedKey' with value '$expectedValue' but actualMap has no such key"
      hasDiff=1
      expectedKeyIdx+=1
    fi
  done

  ((hasDiff)) && exit 1 || return 0
}
