# shellcheck shell=bash

# Early return without logging attempting to source this file if we've already sourced it because this
# script is used in a number of places and we don't want to spam the log.
if ((${sourceGuardSourced:-0} == 1)); then
  return 0
fi

# sourceGuard ensures:
#
# - the script is sourced at most once per build
# - the script must be in a dependency array such that the script is a build-time dependency
# - the script exists and is readable
sourceGuard() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments, but got $#!"
    nixErrorLog "usage: sourceGuard guardName script"
    exit 1
  fi

  local -r guardName="$1"
  local -nr guardNameSourcedRef="${guardName}Sourced"
  local -nr guardNameSourcedScriptRef="${!guardNameSourcedRef}Script"
  local -nr guardNameSourcedHostOffsetRef="${!guardNameSourcedRef}HostOffset"
  local -nr guardNameSourcedTargetOffsetRef="${!guardNameSourcedRef}TargetOffset"
  local -r script="$2"

  printCurrent() {
    echo -n \
      "guardName=$guardName" \
      "script=$script" \
      "hostOffset=${hostOffset:-0}" \
      "targetOffset=${targetOffset:-0}"
  }

  printStored() {
    echo -n \
      "guardName=$guardName" \
      "script=${guardNameSourcedScriptRef:?}" \
      "hostOffset=${guardNameSourcedHostOffsetRef:?}" \
      "targetOffset=${guardNameSourcedTargetOffsetRef:?}"
  }

  # Check arguments
  if [[ -z $guardName ]]; then
    nixErrorLog "guardName argument for script $script must not be empty"
    exit 1
  elif [[ ! -f $script || ! -r $script ]]; then
    nixErrorLog "guardName $guardName supplied script $script which is not a readable file"
    exit 1
  fi

  # Check if we have already sourced the script
  if ((${guardNameSourcedRef:-0})); then
    nixInfoLog "skipping sourcing $(printCurrent) because we have already sourced $(printStored)"
    return 0
  elif [[ -n ${strictDeps:-} && ${hostOffset:?} -ge 0 ]]; then
    nixInfoLog "skipping sourcing $(printCurrent) because it is not a build-time dependency"
    return 0
  fi

  declare -gir "${!guardNameSourcedRef}"=1
  declare -gr "${!guardNameSourcedScriptRef}"="$script"
  declare -gir "${!guardNameSourcedHostOffsetRef}"="${hostOffset:-0}"
  declare -gir "${!guardNameSourcedTargetOffsetRef}"="${targetOffset:-0}"
  nixInfoLog "sourcing $(printStored)"
  # shellcheck disable=SC1090
  source "$script" || {
    nixErrorLog "failed to source $(printStored)"
    exit 1
  }

  # Unset functions so they are not visible to sourced script after sourceGuard is invoked.
  unset -f printCurrent
  unset -f printStored

  return 0
}

# If we've not already sourced this file, try to source it, and make sourceGuard readonly if we were successfull.
if ((${sourceGuardSourced:-0} == 0)); then
  sourceGuard "sourceGuard" "${BASH_SOURCE[0]}"
  if ((${sourceGuardSourced:-0} == 1)); then
    declare -fgr sourceGuard
  fi
fi

return 0
