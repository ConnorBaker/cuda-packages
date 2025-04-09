# shellcheck shell=bash

# TODO(@connorbaker): Why this offset?
if ((${hostOffset:?} != -1)); then
  nixInfoLog "skipping sourcing nvccHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"
  return 0
fi
nixLog "sourcing nvccHook.bash (hostOffset=${hostOffset:?}) (targetOffset=${targetOffset:?})"

# NOTE: This flag is duplicated in all CUDA setup hooks which modify ELF files to ensure consistency.
# patchelf defaults to using RUNPATH, so to preserve RPATH we need to be uniform.
declare -ig cudaForceRpath="@cudaForceRpath@"

declare -ig nvccHostCCMatchesStdenvCC="@nvccHostCCMatchesStdenvCC@"
declare -ig dontCompressCudaFatbin=${dontCompressCudaFatbin:-0}
declare -ig dontNvccRunpathFixup=${dontNvccRunpathFixup:-0}
declare -ig dontNvccRunpathCheck=${dontNvccRunpathCheck:-0}

# NOTE: `appendToVar` does not export the variable to the environment because it is assumed to be a shell
# variable. To avoid variables being locally scoped, we must export it prior to adding values.
export NVCC_PREPEND_FLAGS="${NVCC_PREPEND_FLAGS:-}"
export NVCC_APPEND_FLAGS="${NVCC_APPEND_FLAGS:-}"

# Declare the variable to avoid occursInArray throwing an error if it doesn't exist.
declare -ag prePhases
declare -ag postInstallCheckHooks

# NOTE: Add to prePhases to ensure all setup hooks are sourced prior to running the order check.
# TODO(@connorbaker): Due to the order Nixpkgs setup sources files, dependencies are not sourced
# prior to the current node. As such, even though we have occursInArray as one of our propagated
# build inputs, we cannot use it at the time the hook is sourced.
# See: https://github.com/NixOS/nixpkgs/pull/31414
prePhases+=(nvccHookRegistration)
nixLog "added nvccHookRegistration to prePhases"

# Registering during prePhases ensures that all setup hooks are sourced prior to installing ours,
# allowing us to always go after autoAddDriverRunpath and autoPatchelfHook.
nvccHookRegistration() {
  if occursInArray nvccSetupEnvironmentVariables preConfigureHooks; then
    nixLog "skipping nvccSetupEnvironmentVariables, already present in preConfigureHooks"
  else
    preConfigureHooks+=(nvccSetupEnvironmentVariables)
    nixLog "added nvccSetupEnvironmentVariables to preConfigureHooks"
  fi

  # If the host compiler does not match the stdenv compiler, we need to prevent NVCC from leaking the host compiler
  # into the build.
  if ! ((nvccHostCCMatchesStdenvCC)); then
    # NOTE: We must quote the key names otherwise shfmt throws errors such as
    # not a valid arithmetic operator: cudaStdenvCCUnwrappedCCRoot@
    declare -Agr nvccForbiddenHostCompilerRunpathEntries=(
      # Compiler libraries
      ["@cudaStdenvCCUnwrappedCCRoot@/lib"]="@stdenvCCUnwrappedCCRoot@/lib"
      ["@cudaStdenvCCUnwrappedCCRoot@/lib64"]="@stdenvCCUnwrappedCCRoot@/lib64"
      ["@cudaStdenvCCUnwrappedCCRoot@/gcc/@cudaStdenvCCHostPlatformConfig@/@cudaStdenvCCVersion@"]="@stdenvCCUnwrappedCCRoot@/gcc/@stdenvCCHostPlatformConfig@/@stdenvCCVersion@"
      # Compiler library
      ["@cudaStdenvCCUnwrappedCCLibRoot@/lib"]="@stdenvCCUnwrappedCCLibRoot@/lib"
    )

    # Tell CMake to ignore libraries provided by NVCC's host compiler when linking.
    if occursInArray nvccSetupCMakeHostCompilerLeakPrevention preConfigureHooks; then
      nixLog "skipping nvccSetupCMakeHostCompilerLeakPrevention, already present in preConfigureHooks"
    else
      preConfigureHooks+=(nvccSetupCMakeHostCompilerLeakPrevention)
      nixLog "added nvccSetupCMakeHostCompilerLeakPrevention to preConfigureHooks"
    fi

    # Remove references to forbidden paths in output ELF files.
    if ! ((dontNvccRunpathFixup)); then
      if occursInArray "autoFixElfFiles nvccRunpathFixup" postFixupHooks; then
        nixLog "skipping 'autoFixElfFiles nvccRunpathFixup', already present in postFixupHooks"
      else
        postFixupHooks+=("autoFixElfFiles nvccRunpathFixup")
        nixLog "added 'autoFixElfFiles nvccRunpathFixup' to postFixupHooks"
      fi
    fi

    # Check for references to forbidden paths in the output files.
    if ! ((dontNvccRunpathCheck)); then
      if occursInArray nvccRunpathCheck postInstallCheckHooks; then
        nixLog "skipping nvccRunpathCheck, already present in postInstallCheckHooks"
      else
        postInstallCheckHooks+=(nvccRunpathCheck)
        nixLog "added nvccRunpathCheck to postInstallCheckHooks"
      fi
    fi
  fi

  return 0
}

nvccSetupEnvironmentVariables() {
  # NOTE: Historically, we would set the following flags:
  # -DCUDA_HOST_COMPILER=@cudaStdenvCCFullPath@
  # -DCMAKE_CUDA_HOST_COMPILER=@cudaStdenvCCFullPath@
  # However, as of CMake 3.13, if CUDAHOSTCXX is set, CMake will automatically use it as the host compiler for CUDA.
  # Since we set CUDAHOSTCXX in cudaSetupEnvironmentVariables, we don't need to set these flags anymore.

  # Set CUDAHOSTCXX if unset or null
  # https://cmake.org/cmake/help/latest/envvar/CUDAHOSTCXX.html
  if [[ -z ${CUDAHOSTCXX:-} ]]; then
    export CUDAHOSTCXX="@cudaStdenvCCFullPath@"
    nixLog "set CUDAHOSTCXX to $CUDAHOSTCXX"
  fi

  # NOTE: CUDA 12.5 and later allow setting NVCC_CCBIN as a lower-precedent way of using -ccbin.
  # https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/index.html#compiler-bindir-directory-ccbin
  export NVCC_CCBIN="@cudaStdenvCCFullPath@"
  nixLog "set NVCC_CCBIN to @cudaStdenvCCFullPath@"

  # We append --compiler-bindir because NVCC uses the last --compiler-bindir it gets on the command line.
  # If users are able to be trusted to specify NVCC's host compiler, they can filter out this arg.
  # NOTE: Warnings of the form
  # nvcc warning : incompatible redefinition for option 'compiler-bindir', the last value of this option was used
  # indicate something in the build system is specifying `--compiler-bindir` (or `-ccbin`) and should be patched.
  appendToVar NVCC_APPEND_FLAGS "--compiler-bindir=@cudaStdenvCCFullPath@"
  nixLog "appended --compiler-bindir=@cudaStdenvCCFullPath@ to NVCC_APPEND_FLAGS"

  # NOTE: We set -Xfatbin=-compress-all, which reduces the size of the compiled
  #   binaries. If binaries grow over 2GB, they will fail to link. This is a problem for us, as
  #   the default set of CUDA capabilities we build can regularly cause this to occur (for
  #   example, with Magma).
  #
  # @SomeoneSerge: original comment was made by @ConnorBaker in .../cudatoolkit/common.nix
  if ! ((dontCompressCudaFatbin)); then
    appendToVar NVCC_PREPEND_FLAGS "-Xfatbin=-compress-all"
    nixLog "appended -Xfatbin=-compress-all to NVCC_PREPEND_FLAGS"
  fi

  return 0
}

nvccSetupCMakeHostCompilerLeakPrevention() {
  # If CMake is not present, skip setting CMake flags.
  if ! command -v cmake &>/dev/null; then
    return 0
  fi

  # Instruct CMake to ignore libraries provided by NVCC's host compiler when linking, as these should be supplied by
  # the stdenv's compiler.
  # TODO(@connorbaker): Order of key traversal is not guaranteed!
  local forbiddenEntry
  for forbiddenEntry in "${!nvccForbiddenHostCompilerRunpathEntries[@]}"; do
    addToSearchPathWithCustomDelimiter ";" CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES_EXCLUDE "$forbiddenEntry"
    nixLog "appended $forbiddenEntry to CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES_EXCLUDE"
  done

  return 0
}

nvccRunpathFixup() {
  local -r path="$1"

  # Get the original runpath entries.
  # shellcheck disable=SC2034
  local -a originalRunpathEntries=()
  getRunpathEntries "$path" originalRunpathEntries || return 0 # Fails if ELF is statically linked.

  # Replace the forbidden entries.
  # shellcheck disable=SC2034
  local -a newRunpathEntries=()
  arrayReplace originalRunpathEntries nvccForbiddenHostCompilerRunpathEntries $'\0' newRunpathEntries

  local -r originalRunpathString="$(concatStringsSep ":" originalRunpathEntries)"
  local -r newRunpathString="$(concatStringsSep ":" newRunpathEntries)"
  if [[ $originalRunpathString != "$newRunpathString" ]]; then
    # Always error log when we made replacements -- this is a sign of a broken build.
    nixErrorLog "found forbidden paths, replacing rpath of $path: $originalRunpathString -> $newRunpathString"
    if ((cudaForceRpath)); then
      patchelf --remove-rpath "$path"
      patchelf --force-rpath --set-rpath "$newRunpathString" "$path"
    else
      patchelf --set-rpath "$newRunpathString" "$path"
    fi
  fi

  return 0
}

nvccRunpathCheck() {
  nixLog "checking for references to forbidden paths..."
  local -a outputPaths=()
  local matches

  local runpathEntry
  local -a grepArgs=(
    --max-count=5
    --recursive
    --exclude=LICENSE
  )
  for runpathEntry in "${!nvccForbiddenHostCompilerRunpathEntries[@]}"; do
    grepArgs+=(-e "$runpathEntry")
  done

  mapfile -t outputPaths < <(for o in $(getAllOutputNames); do echo "${!o:?}"; done)
  matches="$(grep "${grepArgs[@]}" "${outputPaths[@]}")" || true
  if [[ -n $matches ]]; then
    nixErrorLog "detected references to forbidden paths: $matches"
    exit 1
  fi

  return 0
}
