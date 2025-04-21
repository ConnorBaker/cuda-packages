# shellcheck shell=bash

# cudaHook should only run when in nativeBuildInputs or the like.
if [[ -n ${strictDeps:-} && ${hostOffset:-0} -ne -1 ]]; then
  nixInfoLog "skipping sourcing cudaHook.bash (hostOffset=${hostOffset:-0}) (targetOffset=${targetOffset:-0})"
  return 0
elif ((${cudaHookSourced:-0})); then
  nixInfoLog "skipping sourcing cudaHook.bash (cudaHookSourced=${cudaHookSourced:-0})"
  return 0
fi
nixLog "sourcing cudaHook.bash (hostOffset=${hostOffset:-0}) (targetOffset=${targetOffset:-0})"
declare -gir cudaHookSourced=1

# TODO(@connorbaker): Guard against being sourced multiple times.
declare -Ag cudaHostPathsSeen

# NOTE: Add to prePhases to ensure all setup hooks are sourced prior to running the order check.
# TODO(@connorbaker): Due to the order Nixpkgs setup sources files, dependencies are not sourced
# prior to the current node. As such, even though we have occursInArray as one of our propagated
# build inputs, we cannot use it at the time the hook is sourced.
# See: https://github.com/NixOS/nixpkgs/pull/31414
# TODO: We don't use structuredAttrs/arrays universally, so don't worry about idempotency.
appendToVar prePhases cudaHookRegistration
nixLog "added cudaHookRegistration to prePhases"

# We use the `targetOffset` to choose the right env hook to accumulate the right
# sort of deps (those with that offset).
# NOTE: addEnvHooks must occur before the prePhases are run, so we must
# register the hook here.
addEnvHooks "${targetOffset:-0}" cudaSetupCudaToolkitRoot
nixLog "added cudaSetupCudaToolkitRoot to envHooks for targetOffset=${targetOffset:-0}"

cudaHookRegistration() {
  # TODO: We don't use structuredAttrs/arrays universally, so don't worry about idempotency.
  appendToVar preConfigureHooks cudaSetupCMakeFlags
  nixLog "added cudaSetupCMakeFlags to preConfigureHooks"

  # NOTE: setup.sh uses recordPropagatedDependencies in fixupPhase, which overwrites dependency files, so we must run
  # in postFixup.
  # TODO: We don't use structuredAttrs/arrays universally, so don't worry about idempotency.
  appendToVar postFixupHooks cudaPropagateLibraries
  nixLog "added cudaPropagateLibraries to postFixupHooks"

  return 0
}

cudaSetupCudaToolkitRoot() {
  if [[ -f "$1/nix-support/include-in-cudatoolkit-root" ]]; then
    cudaHostPathsSeen[$1]=1
    addToSearchPathWithCustomDelimiter ";" CUDAToolkit_ROOT "$1"
    nixLog "added $1 to CUDAToolkit_ROOT"
  else
    nixInfoLog "skipping $1, not marked for inclusion by cudaHook"
  fi

  return 0
}

cudaSetupCMakeFlags() {
  # If CMake is not present, skip setting CMake flags.
  if ! command -v cmake &>/dev/null; then
    nixInfoLog "skipping cudaSetupCMakeFlags, CMake not found"
    return 0
  fi

  # TODO: Check if this is already present in cmakeFlags before adding.
  appendToVar cmakeFlags "-DCMAKE_POLICY_DEFAULT_CMP0074=NEW"
  nixLog "appended -DCMAKE_POLICY_DEFAULT_CMP0074=NEW to cmakeFlags"

  return 0
}

# TODO: This doesn't account for offsets.
cudaPropagateLibraries() {
  nixInfoLog "running with cudaPropagateToOutput=${cudaPropagateToOutput:-} cudaHostPathsSeen=${!cudaHostPathsSeen[*]}"

  [[ -z ${cudaPropagateToOutput:-} ]] && return 0

  mkdir -p "${!cudaPropagateToOutput:?}/nix-support"
  # One'd expect this should be propagated-bulid-build-deps, but that doesn't seem to work
  printWords "@cudaHook@" >>"${!cudaPropagateToOutput:?}/nix-support/propagated-native-build-inputs"
  nixLog "added cudaHook to the propagatedNativeBuildInputs of output ${!cudaPropagateToOutput:?}"

  local propagatedBuildInputs=("${!cudaHostPathsSeen[@]}")
  local output
  for output in $(getAllOutputNames); do
    if [[ $output != "${cudaPropagateToOutput:?}" ]]; then
      propagatedBuildInputs+=("${!output:?}")
    fi
    break
  done

  # One'd expect this should be propagated-host-host-deps, but that doesn't seem to work
  printWords "${propagatedBuildInputs[@]}" >>"${!cudaPropagateToOutput:?}/nix-support/propagated-build-inputs"
  nixLog "added ${propagatedBuildInputs[*]} to the propagatedBuildInputs of output ${!cudaPropagateToOutput:?}"

  return 0
}
