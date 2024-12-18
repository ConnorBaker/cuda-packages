# shellcheck shell=bash

noBrokenSymlinks() {
  local -r output="${1:?}"
  local path
  local pathParent
  local symlinkTarget
  local errorMessage
  local -i numBrokenSymlinks=0
  local -i numReflexiveSymlinks=0

  # TODO(@connorbaker): This hook doesn't check for cycles in symlinks.

  if [[ ! -e $output ]]; then
    nixWarnLog "skipping non-existent output $output"
    return 0
  fi
  nixLog "running on $output"

  # NOTE: path is absolute because we're running `find` against an absolute path (`output`).
  while IFS= read -r -d $'\0' path; do
    pathParent="$(dirname "$path")"
    symlinkTarget="$(readlink "$path")"

    # Canonicalize symlinkTarget to an absolute path.
    if [[ $symlinkTarget == /* ]]; then
      nixInfoLog "symlink $path points to absolute target $symlinkTarget"
    else
      nixInfoLog "symlink $path points to relative target $symlinkTarget"
      symlinkTarget="$pathParent/$symlinkTarget"

      # Check to make sure the interpolated target doesn't escape the store path of `output`.
      # If it does, Nix probably won't be able to resolve or track dependencies.
      if [[ $symlinkTarget != "$output" && $symlinkTarget != "$output"/* ]]; then
        nixErrorLog "symlink $path points to target $symlinkTarget, which escapes the current store path $output"
        return 1
      fi
    fi

    if [[ ! -e $symlinkTarget ]]; then
      # symlinkTarget does not exist
      errorMessage="the symlink $path points to a missing target $symlinkTarget"
      if [[ -z ${allowBrokenSymlinks-} ]]; then
        nixErrorLog "$errorMessage"
        numBrokenSymlinks+=1
      else
        nixInfoLog "$errorMessage"
      fi

    elif [[ $path == "$symlinkTarget" ]]; then
      # symlinkTarget is exists and is reflexive
      errorMessage="the symlink $path is reflexive $symlinkTarget"
      if [[ -z ${allowReflexiveSymlinks-} ]]; then
        nixErrorLog "$errorMessage"
        numReflexiveSymlinks+=1
      else
        nixInfoLog "$errorMessage"
      fi

    else
      # symlinkTarget exists and is irreflexive
      nixInfoLog "the symlink $path is irreflexive and points to a target which exists"
    fi
  done < <(find "$output" -type l -print0)

  if ((numBrokenSymlinks > 0 || numReflexiveSymlinks > 0)); then
    nixErrorLog "found $numBrokenSymlinks broken symlinks and $numReflexiveSymlinks reflexive symlinks"
    return 1
  fi
  return 0
}

noBrokenSymlinksInAllOutputs() {
  for output in $(getAllOutputNames); do
    noBrokenSymlinks "${!output}"
  done
}

# shellcheck disable=SC1091
source @nixLogWithLevelAndFunctionNameHook@

# symlinks are often created in postFixup
# don't use fixupOutputHooks, it is before postFixup
postFixupHooks+=(noBrokenSymlinksInAllOutputs)
nixLog "added noBrokenSymlinksInAllOutputs to postFixupHooks"
