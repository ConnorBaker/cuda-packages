# shellcheck shell=bash

# Only run the hook from nativeBuildInputs
if ((${hostOffset:?} == -1 && ${targetOffset:?} == 0)); then
  # shellcheck disable=SC1091
  source @nixLogWithLevelAndFunctionNameHook@
  nixLog "sourcing setup-cuda-hook.sh"
else
  return 0
fi

if (("${cudaSetupHookOnce:-0}" > 0)); then
  nixWarnLog "skipping because the hook has been propagated more than once"
  return 0
fi

declare -ig cudaSetupHookOnce=1
declare -Ag cudaHostPathsSeen=()

preConfigureHooks+=(setupCUDAPopulateArrays)
nixLog "added setupCUDAPopulateArrays to preConfigureHooks"

setupCUDAPopulateArrays() {
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

preConfigureHooks+=(setupCUDAEnvironmentVariables)
nixLog "added setupCUDAEnvironmentVariables to preConfigureHooks"

setupCUDAEnvironmentVariables() {
  nixInfoLog "running with cudaHostPathsSeen=${!cudaHostPathsSeen[*]}"

  for path in "${!cudaHostPathsSeen[@]}"; do
    addToSearchPathWithCustomDelimiter ";" CUDAToolkit_ROOT "$path"
    nixLog "added $path to CUDAToolkit_ROOT"
    if [[ -d "$path/include" ]]; then
      addToSearchPathWithCustomDelimiter ";" CUDAToolkit_INCLUDE_DIR "$path/include"
      nixLog "added $path/include to CUDAToolkit_INCLUDE_DIR"
    fi
  done

  # Set CUDAHOSTCXX if unset or null
  # https://cmake.org/cmake/help/latest/envvar/CUDAHOSTCXX.html
  if [[ -z ${CUDAHOSTCXX:-} ]]; then
    export CUDAHOSTCXX="@ccFullPath@"
    nixLog "set CUDAHOSTCXX to $CUDAHOSTCXX"
  fi

  # Set CUDAARCHS if unset or null
  # https://cmake.org/cmake/help/latest/envvar/CUDAARCHS.html
  if [[ -z ${CUDAARCHS:-} ]]; then
    export CUDAARCHS="@cudaArchs@"
    nixLog "set CUDAARCHS to $CUDAARCHS"
  fi

  # For non-CMake projects:
  # We prepend --compiler-bindir to nvcc flags.
  # Downstream packages can override these, because NVCC
  # uses the last --compiler-bindir it gets on the command line.
  # https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/index.html#compiler-bindir-directory-ccbin
  # NOTE: Using "--compiler-bindir" results in "incompatible redefinition"
  # warnings, while using the short form "-ccbin" does not... more often than not.
  # Perhaps the two forms can't exist in the same command line?
  appendToVar NVCC_PREPEND_FLAGS "-ccbin @ccFullPath@"
  nixLog "appended -ccbin @ccFullPath@ to NVCC_PREPEND_FLAGS"

  # NOTE: CUDA 12.5 and later allow setting NVCC_CCBIN as a lower-precedent way of using -ccbin.
  export NVCC_CCBIN="@ccFullPath@"
  nixLog "set NVCC_CCBIN to @ccFullPath@"

  # NOTE: We set -Xfatbin=-compress-all, which reduces the size of the compiled
  #   binaries. If binaries grow over 2GB, they will fail to link. This is a problem for us, as
  #   the default set of CUDA capabilities we build can regularly cause this to occur (for
  #   example, with Magma).
  #
  # @SomeoneSerge: original comment was made by @ConnorBaker in .../cudatoolkit/common.nix
  if [[ -z ${cudaDontCompressFatbin:-} ]]; then
    appendToVar NVCC_PREPEND_FLAGS "-Xfatbin=-compress-all"
    nixLog "appended -Xfatbin=-compress-all to NVCC_PREPEND_FLAGS"
  fi
}

preConfigureHooks+=(setupCUDACmakeFlags)
nixLog "added setupCUDACmakeFlags to preConfigureHooks"

setupCUDACmakeFlags() {
  # If CMake is not present, don't set the flags.
  if ! command -v cmake &>/dev/null; then
    return 0
  fi

  # NOTE: Historically, we would set the following flags:
  # -DCUDA_HOST_COMPILER=@ccFullPath@
  # -DCMAKE_CUDA_HOST_COMPILER=@ccFullPath@
  # However, as of CMake 3.13, if CUDAHOSTCXX is set, CMake will automatically use it as the host compiler for CUDA.
  # Since we set CUDAHOSTCXX in setupCUDAEnvironmentVariables, we don't need to set these flags anymore.

  # TODO: Should we default to enabling support if CMake is present and the flag is not set?
  if (("${cudaEnableCmakeFindCudaSupport:-0}" == 1)); then
    appendToVar cmakeFlags "-DCUDAToolkit_INCLUDE_DIR=${CUDAToolkit_INCLUDE_DIR:-}"
    nixLog "appended -DCUDAToolkit_INCLUDE_DIR=${CUDAToolkit_INCLUDE_DIR:-} to cmakeFlags"
    appendToVar cmakeFlags "-DCUDAToolkit_ROOT=${CUDAToolkit_ROOT:-}"
    nixLog "appended -DCUDAToolkit_ROOT=${CUDAToolkit_ROOT:-} to cmakeFlags"
  fi

  # Support the legacy flag -DCUDA_TOOLKIT_ROOT_DIR
  if (("${cudaEnableCmakeFindCudaToolkitSupport:-0}" == 1)); then
    appendToVar cmakeFlags "-DCUDA_TOOLKIT_ROOT_DIR=${CUDAToolkit_ROOT:-}"
    nixLog "appended -DCUDA_TOOLKIT_ROOT_DIR=${CUDAToolkit_ROOT:-} to cmakeFlags"
  fi
}

postFixupHooks+=(propagateCudaLibraries)
nixLog "added propagateCudaLibraries to postFixupHooks"

propagateCudaLibraries() {
  nixInfoLog "running with cudaPropagateToOutput=$cudaPropagateToOutput cudaHostPathsSeen=${!cudaHostPathsSeen[*]}"

  [[ -z ${cudaPropagateToOutput:-} ]] && return 0

  mkdir -p "${!cudaPropagateToOutput}/nix-support"
  # One'd expect this should be propagated-bulid-build-deps, but that doesn't seem to work
  printWords "@setupCudaHook@" >>"${!cudaPropagateToOutput}/nix-support/propagated-native-build-inputs"
  nixLog "added setupCudaHook to the propagatedNativeBuildInputs of output $cudaPropagateToOutput"

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
