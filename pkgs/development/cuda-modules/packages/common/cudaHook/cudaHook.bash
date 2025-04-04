# shellcheck shell=bash

# TODO(@connorbaker): Why this offset?
if ((${hostOffset:?} != -1)); then
  nixInfoLog "skipping sourcing cudaHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"
  return 0
fi
nixLog "sourcing cudaHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"

# TODO(@connorbaker): Guard against being sourced multiple times.
declare -Ag cudaHostPathsSeen

cudaHookRegistration() {
  # We use the `targetOffset` to choose the right env hook to accumulate the right
  # sort of deps (those with that offset).
  addEnvHooks "${targetOffset:?}" cudaSetupCudaToolkitRoot
  nixLog "added cudaSetupCudaToolkitRoot to envHooks for targetOffset=${targetOffset:?}"

  if occursInArray cudaSetupCMakeFlags preConfigureHooks; then
    nixLog "skipping cudaSetupCMakeFlags, already present in preConfigureHooks"
  else
    preConfigureHooks+=(cudaSetupCMakeFlags)
    nixLog "added cudaSetupCMakeFlags to preConfigureHooks"
  fi

  # NOTE: setup.sh uses recordPropagatedDependencies in fixupPhase, which overwrites dependency files, so we must run
  # in postFixup.
  if occursInArray cudaPropagateLibraries postFixupHooks; then
    nixLog "skipping cudaPropagateLibraries, already present in postFixupHooks"
  else
    postFixupHooks+=(cudaPropagateLibraries)
    nixLog "added cudaPropagateLibraries to postFixupHooks"
  fi

  return 0
}

cudaHookRegistration

cudaSetupCudaToolkitRoot() {
  if [[ -f "$1/nix-support/include-in-cudatoolkit-root" ]]; then
    cudaHostPathsSeen["$1"]=1
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
