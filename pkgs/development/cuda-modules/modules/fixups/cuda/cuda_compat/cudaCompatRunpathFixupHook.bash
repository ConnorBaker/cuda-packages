# shellcheck shell=bash

# TODO(@connorbaker): Why this offset?
# Stubs are a used during linking, so we only want to run if we're in buildInputs.
if [[ -n ${strictDeps:-} && ${hostOffset:-0} -ne 0 ]]; then
  nixInfoLog "skipping sourcing cudaCompatRunpathFixupHook.bash (hostOffset=${hostOffset:-0}) (targetOffset=${targetOffset:-0})"
  return 0
fi
nixLog "sourcing cudaCompatRunpathFixupHook.bash (hostOffset=${hostOffset:-0}) (targetOffset=${targetOffset:-0})"

# NOTE: This flag is duplicated in all CUDA setup hooks which modify ELF files to ensure consistency.
# patchelf defaults to using RUNPATH, so to preserve RPATH we need to be uniform.
declare -ig cudaForceRpath="@cudaForceRpath@"

# NOTE: Add to prePhases to ensure all setup hooks are sourced prior to running the order check.
# TODO(@connorbaker): Due to the order Nixpkgs setup sources files, dependencies are not sourced
# prior to the current node. As such, even though we have occursInArray as one of our propagated
# build inputs, we cannot use it at the time the hook is sourced.
# See: https://github.com/NixOS/nixpkgs/pull/31414
# TODO: We don't use structuredAttrs/arrays universally, so don't worry about idempotency.
appendToVar prePhases cudaCompatRunpathFixupHookRegistration
nixLog "added cudaCompatRunpathFixupHookRegistration to prePhases"

# Registering during prePhases ensures that all setup hooks are sourced prior to installing ours,
# allowing us to always go after autoAddDriverRunpath and autoPatchelfHook.
cudaCompatRunpathFixupHookRegistration() {
  # NOTE: setup.sh uses recordPropagatedDependencies in fixupPhase, which overwrites dependency files, so we must run
  # in postFixup.
  # TODO: We don't use structuredAttrs/arrays universally, so don't worry about idempotency.
  appendToVar postFixupHooks "autoFixElfFiles cudaCompatRunpathFixup"
  nixLog "added 'autoFixElfFiles cudaCompatRunpathFixup' to postFixupHooks"

  # May be linked to compat libraries through `out/compat` or symlinks in `lib/lib`.
  # NOTE: Used in cudaCompatRunpathFixup.
  # shellcheck disable=SC2034
  declare -Agr cudaCompatRunpathEntriesToRemove=(
    ["@cudaCompatOutDir@"]=""
    ["@cudaCompatLibDir@"]=""
  )

  return 0
}

cudaCompatRunpathFixup() {
  local -r path="$1"

  # Get the original runpath entries.
  # shellcheck disable=SC2034
  local -a originalRunpathEntries=()
  getRunpathEntries "$path" originalRunpathEntries || return 0 # Fails if ELF is statically linked.

  # Always prepend the runpath with cudaCompatOutDir to give it the highest priority.
  # shellcheck disable=SC2034
  local -a newRunpathEntries=("@cudaCompatOutDir@")

  # Remove the entries that are in cudaCompatRunpathEntriesToRemove from the original runpath.
  arrayReplace originalRunpathEntries cudaCompatRunpathEntriesToRemove $'\0' newRunpathEntries

  # NOTE: cudaCudartRunpathFixupHook handles filtering out and adding a single driverLibDir to the runpath at the end,
  # so we don't need to do that here.

  local -r originalRunpathString="$(concatStringsSep ":" originalRunpathEntries)"
  local -r newRunpathString="$(concatStringsSep ":" newRunpathEntries)"
  if [[ $originalRunpathString != "$newRunpathString" ]]; then
    nixInfoLog "replacing rpath of $path: $originalRunpathString -> $newRunpathString"
    if ((cudaForceRpath)); then
      patchelf --remove-rpath "$path"
      patchelf --force-rpath --set-rpath "$newRunpathString" "$path"
    else
      patchelf --set-rpath "$newRunpathString" "$path"
    fi
  fi

  return 0
}
