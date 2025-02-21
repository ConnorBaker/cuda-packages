# shellcheck shell=bash

set -eu

declare -ag files=()

# shellcheck disable=SC2034
declare -ag preScriptHooks=(gatherFiles)

# Register testers when they have something to test
declare -ag testers=()
# shellcheck disable=SC2154
{
  ((${#included[@]})) && testers+=(testIncluded)
  ((${#excluded[@]})) && testers+=(testExcluded)

  ((${#includedWhenAnyIncluded[@]})) && testers+=(testIncludedWhenAnyIncluded)
  ((${#includedWhenAllIncluded[@]})) && testers+=(testIncludedWhenAllIncluded)
  ((${#includedWhenAnyExcluded[@]})) && testers+=(testIncludedWhenAnyExcluded)
  ((${#includedWhenAllExcluded[@]})) && testers+=(testIncludedWhenAllExcluded)
  ((${#excludedWhenAnyIncluded[@]})) && testers+=(testExcludedWhenAnyIncluded)
  ((${#excludedWhenAllIncluded[@]})) && testers+=(testExcludedWhenAllIncluded)
  ((${#excludedWhenAnyExcluded[@]})) && testers+=(testExcludedWhenAnyExcluded)
  ((${#excludedWhenAllExcluded[@]})) && testers+=(testExcludedWhenAllExcluded)

  ((${#precedes[@]})) && testers+=(testPrecedes)
  ((${#succeeds[@]})) && testers+=(testSucceeds)
}

isInDelimitedString() {
  local -r substring="$1"
  local -r delimiter="$2"
  local -r string="$3"

  [[ $delimiter$string$delimiter == *$delimiter$substring$delimiter* ]]
}

isPrecededByInDelimitedString() {
  local -r substring="$1"
  local -r preceding="$2"
  local -r delimiter="$3"
  local -r string="$4"

  [[ $delimiter$string$delimiter == *$delimiter$preceding$delimiter*$delimiter$substring$delimiter* ||
    $delimiter$string$delimiter == *$delimiter$preceding$delimiter$substring$delimiter* ]]
}

isSucceededByInDelimitedString() {
  local -r substring="$1"
  local -r succeeding="$2"
  local -r delimiter="$3"
  local -r string="$4"

  [[ $delimiter$string$delimiter == *$delimiter$substring$delimiter*$delimiter$succeeding$delimiter* ||
    $delimiter$string$delimiter == *$delimiter$substring$delimiter$succeeding$delimiter* ]]
}

gatherFiles() {
  # Get all files under `testRunpathRoot` which match `includeGlob` and not `excludeGlob`.
  # shellcheck disable=SC2154
  nixLog "searching for files in ${testRunpathRoot:?} using includeGlob=${includeGlob@Q} and excludeGlob=${excludeGlob@Q}"

  while IFS= read -r -d '' file; do
    # We need globbing
    # shellcheck disable=SC2053
    if [[ $file != ${includeGlob?} ]]; then
      nixLog "excluding $file because it doesn't match includeGlob"
      continue
    fi

    # We need globbing
    # shellcheck disable=SC2053
    if [[ $file == ${excludeGlob?} ]]; then
      nixLog "excluding $file because it matches excludeGlob"
      continue
    fi

    if ! isELF "$file"; then
      nixLog "excluding $file because it's not an ELF file"
      continue
    fi

    nixLog "including $file"
    files+=("$file")
  done < <(find "$testRunpathRoot" -type f -print0)

  return 0
}

testIncluded() {
  local -r file="$1"
  local -r runpath="$2"
  local -i hasFailed=0

  # shellcheck disable=SC2154
  for entry in "${included[@]}"; do
    if ! isInDelimitedString "$entry" : "$runpath"; then
      nixErrorLog "$entry not found in runpath of $file"
      hasFailed=1
    fi
  done

  return $hasFailed
}

testExcluded() {
  local -r file="$1"
  local -r runpath="$2"
  local -i hasFailed=0

  # shellcheck disable=SC2154
  for entry in "${excluded[@]}"; do
    if isInDelimitedString "$entry" : "$runpath"; then
      nixErrorLog "$entry found in runpath of $file"
      hasFailed=1
    fi
  done

  return $hasFailed
}

testPrecedes() {
  local -r file="$1"
  local -r runpath="$2"
  local -i hasFailed=0

  # shellcheck disable=SC2154
  for preceding in "${!precedes[@]}"; do
    # Space-delimited list of entries to be preceded by $preceding
    for entry in ${precedes[$preceding]}; do
      if isInDelimitedString "$entry" : "$runpath" && ! isPrecededByInDelimitedString "$entry" "$preceding" : "$runpath"; then
        nixErrorLog "$preceding does not precede $entry in runpath of $file"
        hasFailed=1
      fi
    done
  done

  return $hasFailed
}

testSucceeds() {
  local -r file="$1"
  local -r runpath="$2"
  local -i hasFailed=0

  # shellcheck disable=SC2154
  for succeeding in "${!succeeds[@]}"; do
    # Space-delimited list of entries to be succeeded by $succeeding
    for entry in ${succeeds[$succeeding]}; do
      if isInDelimitedString "$entry" : "$runpath" && ! isSucceededByInDelimitedString "$entry" "$succeeding" : "$runpath"; then
        nixErrorLog "$succeeding does not succeed $entry in runpath of $file"
        hasFailed=1
      fi
    done
  done

  return $hasFailed
}

scriptPhase() {
  runHook preScript

  local -i hasFailed=0
  local runpath
  for file in "${files[@]}"; do
    runpath="$(echo -n "$(patchelf --print-rpath "$file")")"
    nixLog "running testers ${testers[*]} against $file with runpath $runpath"
    for tester in "${testers[@]}"; do
      "$tester" "$file" "$runpath" || hasFailed=1
    done
  done

  if ((hasFailed)); then
    nixErrorLog "some files have failed the runpath test"
    exit 1
  fi

  runHook script

  runHook postScript
}

runHook scriptPhase
touch "${out:?}"
