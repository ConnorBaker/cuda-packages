# shellcheck shell=bash

# Only run the hook from nativeBuildInputs
if ((${hostOffset:?} == -1 && ${targetOffset:?} == 0)); then
  # shellcheck disable=SC1091
  source @nixLogWithLevelAndFunctionNameHook@
  nixLog "sourcing cuda-setup-hook.sh"
else
  return 0
fi

if (("${cudaSetupHookOnce:-0}" > 0)); then
  nixWarnLog "skipping because the hook has been propagated more than once"
  return 0
fi

declare -ig cudaSetupHookOnce=1
declare -Ag cudaHostPathsSeen=()

preConfigureHooks+=(cudaSetupPopulateDependencies)
nixLog "added cudaSetupPopulateDependencies to preConfigureHooks"

cudaSetupPopulateDependencies() {
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

  for name in "${dependencyArrayNames[@]}"; do
    nixLog "searching dependencies in $name for CUDA markers"
    local -n deps="$name"
    for dep in "${deps[@]}"; do
      nixInfoLog "checking $dep for CUDA markers"
      if [[ -f "$dep/nix-support/include-in-cudatoolkit-root" ]]; then
        nixLog "found CUDA marker in $dep from $name"
        cudaHostPathsSeen["$dep"]=1
      fi
    done
  done
}

preConfigureHooks+=(cudaSetupEnvironmentVariables)
nixLog "added cudaSetupEnvironmentVariables to preConfigureHooks"

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
}

preConfigureHooks+=(cudaSetupCMakeFlags)
nixLog "added cudaSetupCMakeFlags to preConfigureHooks"

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
}

postFixupHooks+=(cudaPropagateLibraries)
nixLog "added cudaPropagateLibraries to postFixupHooks"

cudaPropagateLibraries() {
  nixInfoLog "running with cudaPropagateToOutput=$cudaPropagateToOutput cudaHostPathsSeen=${!cudaHostPathsSeen[*]}"

  [[ -z ${cudaPropagateToOutput:-} ]] && return 0

  mkdir -p "${!cudaPropagateToOutput}/nix-support"
  # One'd expect this should be propagated-bulid-build-deps, but that doesn't seem to work
  printWords "@cudaSetupHook@" >>"${!cudaPropagateToOutput}/nix-support/propagated-native-build-inputs"
  nixLog "added cudaSetupHook to the propagatedNativeBuildInputs of output $cudaPropagateToOutput"

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
}
