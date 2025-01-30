# shellcheck shell=bash

# Asserts that a map is a submap of another printing out differences if they are not.
# Does not short circuit on the first difference.
assertMapIsSubmap() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: assertMapIsSubmap submapRef supermapRef"
    exit 1
  fi

  local -nr submapRef="$1"
  local -nr supermapRef="$2"

  if [[ ! ${submapRef@a} =~ A ]]; then
    nixErrorLog "first arugment submapRef must be an associative array reference"
    exit 1
  fi

  if [[ ! ${supermapRef@a} =~ A ]]; then
    nixErrorLog "second arugment supermapRef must be an associative array reference"
    exit 1
  fi

  local -a sortedSubmapKeys
  mapfile -d '' -t sortedSubmapKeys < <(printf '%s\0' "${!submapRef[@]}" | sort -z)

  local -a sortedSupermapKeys
  mapfile -d '' -t sortedSupermapKeys < <(printf '%s\0' "${!supermapRef[@]}" | sort -z)

  local -ir submapLength=${#submapRef[@]}
  local -ir supermapLength=${#supermapRef[@]}

  local -i hasDiff=0

  if ((submapLength > supermapLength)); then
    nixErrorLog "submap has more keys than supermap: submap has length $submapLength but supermap has length $supermapLength"
    hasDiff=1
  fi

  local -i submapKeyIdx=0
  local submapKey
  local -i supermapKeyIdx=0
  local supermapKey
  while ((submapKeyIdx < submapLength || supermapKeyIdx < supermapLength)); do
    submapKey="${sortedSubmapKeys[$submapKeyIdx]}"
    supermapKey="${sortedSupermapKeys[$supermapKeyIdx]}"

    if [[ $submapKey < $supermapKey ]]; then
      # In this case the supermap has a key that the submap does not, but that's not a problem since we're
      # testing for submapness.
      supermapKeyIdx=$((supermapKeyIdx + 1))
    elif [[ $submapKey == "$supermapKey" ]]; then
      submapValue="${submapRef["$submapKey"]}"
      supermapValue="${supermapRef["$supermapKey"]}"

      if [[ $submapValue != "$supermapValue" ]]; then
        nixErrorLog "maps differ at key '$submapKey': submap value is '$submapValue' but supermap value is '$supermapValue'"
        hasDiff=1
      fi

      submapKeyIdx=$((submapKeyIdx + 1))
      supermapKeyIdx=$((supermapKeyIdx + 1))
    else
      submapValue="${submapRef["$submapKey"]}"
      nixErrorLog "submap has key '$submapKey' with value '$submapValue' but supermap has no such key"
      hasDiff=1
      submapKeyIdx=$((submapKeyIdx + 1))
    fi
  done

  if ((hasDiff > 0)); then
    exit 1
  fi

  return 0
}
