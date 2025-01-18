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
declare -ag cudaForbiddenRPATHs=(
  # Compiler libraries
  "@unwrappedCCRoot@/lib"
  "@unwrappedCCRoot@/lib64"
  "@unwrappedCCRoot@/gcc/@hostPlatformConfig@/@ccVersion@"
  # Compiler library
  "@unwrappedCCLibRoot@/lib"
)

# NOTE: `appendToVar` does not export the variable to the environment because it is assumed to be a shell
# variable. To avoid variables being locally scoped, we must export it prior to adding values.
export NVCC_PREPEND_FLAGS="${NVCC_PREPEND_FLAGS:-}"
export NVCC_APPEND_FLAGS="${NVCC_APPEND_FLAGS:-}"

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
      addToSearchPathWithCustomDelimiter ";" CUDAToolkit_INCLUDE_DIRS "$path/include"
      nixLog "added $path/include to CUDAToolkit_INCLUDE_DIRS"
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

  # NOTE: CUDA 12.5 and later allow setting NVCC_CCBIN as a lower-precedent way of using -ccbin.
  # https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/index.html#compiler-bindir-directory-ccbin
  export NVCC_CCBIN="@ccFullPath@"
  nixLog "set NVCC_CCBIN to @ccFullPath@"

  # We append --compiler-bindir because NVCC uses the last --compiler-bindir it gets on the command line.
  # If users are able to be trusted to specify NVCC's host compiler, they can filter out this arg.
  # NOTE: Warnings of the form
  # nvcc warning : incompatible redefinition for option 'compiler-bindir', the last value of this option was used
  # indicate something in the build system is specifying `--compiler-bindir` (or `-ccbin`) and should be patched.
  appendToVar NVCC_APPEND_FLAGS "--compiler-bindir=@ccFullPath@"
  nixLog "appended --compiler-bindir=@ccFullPath@ to NVCC_APPEND_FLAGS"

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
  # If CMake is not present, don't set CMake flags.
  if ! command -v cmake &>/dev/null; then
    return 0
  fi

  # NOTE: Historically, we would set the following flags:
  # -DCUDA_HOST_COMPILER=@ccFullPath@
  # -DCMAKE_CUDA_HOST_COMPILER=@ccFullPath@
  # However, as of CMake 3.13, if CUDAHOSTCXX is set, CMake will automatically use it as the host compiler for CUDA.
  # Since we set CUDAHOSTCXX in setupCUDAEnvironmentVariables, we don't need to set these flags anymore.

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

  # Instruct CMake to ignore libraries provided by NVCC's host compiler when linking, as these should be supplied by
  # the stdenv's compiler.
  for forbiddenRPATH in "${cudaForbiddenRPATHs[@]}"; do
    addToSearchPathWithCustomDelimiter ";" CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES_EXCLUDE "$forbiddenRPATH"
    nixLog "appended $forbiddenRPATH to CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES_EXCLUDE"
  done
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

postFixupHooks+=(disallowNVCCHostCompilerLinkLeakageInAllOutputs)
nixLog "added disallowNVCCHostCompilerLinkLeakageInAllOutputs to postFixupHooks"

disallowNVCCHostCompilerLinkLeakage() {
  local -r output="${1:?}"
  local libpath
  local rpath

  if [[ ! -e $output ]]; then
    nixWarnLog "skipping non-existent output $output"
    return 0
  fi
  nixLog "running on $output"

  # NOTE: libpath is absolute because we're running `find` against an absolute path (`output`).
  while IFS= read -r -d $'\0' libpath; do
    while IFS= read -r -d ':' rpath; do
      for forbiddenRPATH in "${cudaForbiddenRPATHs[@]}"; do
        if [[ $rpath == "$forbiddenRPATH"* ]]; then
          nixErrorLog "forbidden path $forbiddenRPATH exists in RPATH of $libpath"
          return 1
        fi
      done
    done < <(patchelf --print-rpath "$libpath" || echo "")
  done < <(find "$output" -type f \( -name '*.so' -o -name '*.so.*' \) -print0)

  return 0
}

disallowNVCCHostCompilerLinkLeakageInAllOutputs() {
  for output in $(getAllOutputNames); do
    disallowNVCCHostCompilerLinkLeakage "${!output}"
  done
}
