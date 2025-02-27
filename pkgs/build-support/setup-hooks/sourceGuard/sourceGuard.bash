# shellcheck shell=bash

if ((${sourceGuardSourced:-0})); then
  nixInfoLog "not sourcing sourceGuard.sh for sourceGuard because it has already been sourced"
  return 0
fi

declare -ig sourceGuardSourced=1

# sourceGuard ensures:
#
# - the script is sourced at most once per build
# - the script must be in nativeBuildInputs
# - the script exists and is readable
#
# As an implementation detail, sourceGuard creates a variable
# <guardName>Sourced which is set to 1 when the script is sourced.
sourceGuard() {
  if (($# != 2)); then
    nixErrorLog "expected two arguments!"
    nixErrorLog "usage: sourceGuard guardName script"
    exit 1
  fi

  local -r guardName="$1"
  local -rn guardNameSourcedRef="${guardName}Sourced"
  local -r script="$2"

  if [[ -z $guardName ]]; then
    nixErrorLog "guardName argument for script $script must not be empty"
    exit 1
  elif [[ ! -f $script || ! -r $script ]]; then
    nixErrorLog "guardName $guardName supplied script $script which is not a readable file"
    exit 1
  fi

  # Only source the script if it is in nativeBuildInputs; it may run code requiring packages unavailable on the target
  # system.
  if ! ((${hostOffset:?} == -1 && ${targetOffset:?} == 0)); then
    nixInfoLog "not sourcing $script for $guardName because it is not in nativeBuildInputs"
  elif ((${guardNameSourcedRef:-0})); then
    nixInfoLog "not sourcing $script for $guardName because it has already been sourced"
  else
    nixInfoLog "sourcing $script for $guardName"
    declare -ig "${!guardNameSourcedRef}"=1
    # shellcheck disable=SC1090
    source "$script" || {
      nixErrorLog "failed to source $script for $guardName"
      exit 1
    }
  fi

  return 0
}
