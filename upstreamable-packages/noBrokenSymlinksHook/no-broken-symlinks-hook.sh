# shellcheck shell=bash
# symlinks are often created in postFixup
# don't use fixupOutputHooks, it is before postFixup
postFixupHooks+=(_noBrokenSymlinksInAllOutputs)

_noBrokenSymlinks() {
  local output="${1:?}"
  local path
  local pathParent
  local symlinkTarget
  local errorMessage
  local -i numBrokenSymlinks=0
  local -i numReflexiveSymlinks=0

  # TODO(@connorbaker): This hook doesn't check for cycles in symlinks.

  if [[ ! -e $output ]]; then
    nixInfoLog "noBrokenSymlinks: skipping non-existent output $output"
    return 0
  else
    nixInfoLog "noBrokenSymlinks: running on $output"
  fi

  # NOTE: path is absolute because we're running `find` against an absolute path (`output`).
  while IFS= read -r -d $'\0' path; do
    pathParent="$(dirname "$path")"
    symlinkTarget="$(readlink "$path")"

    # Canonicalize symlinkTarget to an absolute path.
    if [[ $symlinkTarget == /* ]]; then
      nixInfoLog "noBrokenSymlinks: symlink $path points to absolute target $symlinkTarget"
    else
      nixInfoLog "noBrokenSymlinks: symlink $path points to relative target $symlinkTarget"
      symlinkTarget="$pathParent/$symlinkTarget"

      # Check to make sure the interpolated target doesn't escape the store path of `output`.
      # If it does, Nix probably won't be able to resolve or track dependencies.
      if [[ $symlinkTarget != "$output" && $symlinkTarget != "$output"/* ]]; then
        nixErrorLog "noBrokenSymlinks: symlink $path points to target $symlinkTarget, which escapes the current store path $output"
        return 1
      fi
    fi

    if [[ ! -e $symlinkTarget ]]; then
      # symlinkTarget does not exist
      errorMessage="noBrokenSymlinks: the symlink $path points to a missing target $symlinkTarget"
      if [[ -z ${allowBrokenSymlinks-} ]]; then
        nixErrorLog "$errorMessage"
        numBrokenSymlinks+=1
      else
        nixInfoLog "$errorMessage"
      fi

    elif [[ $path == "$symlinkTarget" ]]; then
      # symlinkTarget is exists and is reflexive
      errorMessage="noBrokenSymlinks: the symlink $path is reflexive $symlinkTarget"
      if [[ -z ${allowReflexiveSymlinks-} ]]; then
        nixErrorLog "$errorMessage"
        numReflexiveSymlinks+=1
      else
        nixInfoLog "$errorMessage"
      fi

    else
      # symlinkTarget exists and is irreflexive
      nixInfoLog "noBrokenSymlinks: the symlink $path is irreflexive and points to a target which exists"
    fi
  done < <(find "$output" -type l -print0)

  if ((numBrokenSymlinks > 0 || numReflexiveSymlinks > 0)); then
    nixErrorLog "noBrokenSymlinks: found $numBrokenSymlinks broken symlinks and $numReflexiveSymlinks reflexive symlinks"
    return 1
  else
    return 0
  fi
}

_noBrokenSymlinksInAllOutputs() {
  for output in $(getAllOutputNames); do
    _noBrokenSymlinks "${!output}"
  done
}
