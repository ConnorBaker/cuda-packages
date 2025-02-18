# shellcheck shell=bash

# Only run the hook from nativeBuildInputs
# shellcheck disable=SC2154
if ((hostOffset == -1 && targetOffset == 0)); then
  nixLog "sourcing cuda-hook.sh"
else
  return 0
fi

if ((${cudaHookOnce:-0})); then
  nixWarnLog "skipping because the hook has been propagated more than once"
  return 0
fi

declare -ig cudaHookOnce=1
declare -Ag cudaHostPathsSeen=()

preConfigureHooks+=(cudaFindAvailablePackages)
nixLog "added cudaFindAvailablePackages to preConfigureHooks"

preConfigureHooks+=(cudaSetupEnvironmentVariables)
nixLog "added cudaSetupEnvironmentVariables to preConfigureHooks"

preConfigureHooks+=(cudaSetupCMakeFlags)
nixLog "added cudaSetupCMakeFlags to preConfigureHooks"

postFixupHooks+=(cudaPropagateLibraries)
nixLog "added cudaPropagateLibraries to postFixupHooks"

cudaFindAvailablePackages() {
  # These names are all guaranteed to be arrays (though they may be empty), with or without __structuredAttrs set.
  # TODO: This function should record *where* it saw each CUDA marker so we can ensure the device offsets are correct.
  # Currently, it lumps them all into the same array, and we use that array to set environment variables.
  local -a dependencyArrayNames=(
    pkgsBuildBuild
    pkgsBuildHost
    pkgsBuildTarget
    pkgsHostHost
    pkgsHostTarget
    pkgsTargetTarget
  )

  for dependencyArrayName in "${dependencyArrayNames[@]}"; do
    nixInfoLog "searching dependencies in $dependencyArrayName for CUDA markers"
    local -n dependencyArray="$dependencyArrayName"
    for dependency in "${dependencyArray[@]}"; do
      nixInfoLog "checking $dependency for CUDA markers"
      if [[ -f "$dependency/nix-support/include-in-cudatoolkit-root" ]]; then
        nixInfoLog "found CUDA marker in $dependency from $dependencyArrayName"
        cudaHostPathsSeen["$dependency"]=1
      fi
    done
  done

  return 0
}

cudaSetupEnvironmentVariables() {
  nixInfoLog "running with cudaHostPathsSeen=${!cudaHostPathsSeen[*]}"

  for path in "${!cudaHostPathsSeen[@]}"; do
    addToSearchPathWithCustomDelimiter ";" CUDAToolkit_ROOT "$path"
    nixLog "added $path to CUDAToolkit_ROOT"
    if [[ -d "$path/include" ]]; then
      addToSearchPathWithCustomDelimiter ";" CUDAToolkit_INCLUDE_DIRS "$path/include"
      nixLog "added $path/include to CUDAToolkit_INCLUDE_DIRS"
    fi
  done

  return 0
}

cudaSetupCMakeFlags() {
  # If CMake is not present, skip setting CMake flags.
  if ! command -v cmake &>/dev/null; then
    return 0
  fi

  if [[ -z ${cudaDisableCmakeFindCudaToolkitSupport:-} ]]; then
    appendToVar cmakeFlags "-DCUDAToolkit_INCLUDE_DIRS=${CUDAToolkit_INCLUDE_DIRS:-}"
    nixLog "appended -DCUDAToolkit_INCLUDE_DIRS=${CUDAToolkit_INCLUDE_DIRS:-} to cmakeFlags"

    appendToVar cmakeFlags "-DCUDAToolkit_ROOT=${CUDAToolkit_ROOT:-}"
    nixLog "appended -DCUDAToolkit_ROOT=${CUDAToolkit_ROOT:-} to cmakeFlags"

    appendToVar cmakeFlags "-DCMAKE_POLICY_DEFAULT_CMP0074=NEW"
    nixLog "appended -DCMAKE_POLICY_DEFAULT_CMP0074=NEW to cmakeFlags"
  else
    # Support the legacy flag -DCUDA_TOOLKIT_ROOT_DIR
    appendToVar cmakeFlags "-DCUDA_TOOLKIT_ROOT_DIR=${CUDAToolkit_ROOT:-}"
    nixLog "appended -DCUDA_TOOLKIT_ROOT_DIR=${CUDAToolkit_ROOT:-} to cmakeFlags"

    appendToVar cmakeFlags "-DCMAKE_POLICY_DEFAULT_CMP0074=OLD"
    nixLog "appended -DCMAKE_POLICY_DEFAULT_CMP0074=OLD to cmakeFlags"
  fi

  return 0
}

cudaPropagateLibraries() {
  nixInfoLog "running with cudaPropagateToOutput=$cudaPropagateToOutput cudaHostPathsSeen=${!cudaHostPathsSeen[*]}"

  [[ -z ${cudaPropagateToOutput:-} ]] && return 0

  mkdir -p "${!cudaPropagateToOutput}/nix-support"
  # One'd expect this should be propagated-bulid-build-deps, but that doesn't seem to work
  printWords "@cudaHook@" >>"${!cudaPropagateToOutput}/nix-support/propagated-native-build-inputs"
  nixLog "added cudaHook to the propagatedNativeBuildInputs of output $cudaPropagateToOutput"

  local propagatedBuildInputs=("${!cudaHostPathsSeen[@]}")
  for output in $(getAllOutputNames); do
    if [[ $output != "$cudaPropagateToOutput" ]]; then
      propagatedBuildInputs+=("${!output}")
    fi
    break
  done

  # One'd expect this should be propagated-host-host-deps, but that doesn't seem to work
  printWords "${propagatedBuildInputs[@]}" >>"${!cudaPropagateToOutput}/nix-support/propagated-build-inputs"
  nixLog "added ${propagatedBuildInputs[*]} to the propagatedBuildInputs of output $cudaPropagateToOutput"

  return 0
}
