# shellcheck shell=bash

# Only run the hook from nativeBuildInputs
# shellcheck disable=SC2154
if ((hostOffset == -1 && targetOffset == 0)); then
  nixLog "sourcing nvcc-hook.sh"
else
  return 0
fi

if ((${nvccHookOnce:-0})); then
  nixWarnLog "skipping because the hook has been propagated more than once"
  return 0
fi

declare -ig nvccHookOnce=1
declare -ig nvccHostCCMatchesStdenvCC="@nvccHostCCMatchesStdenvCC@"
declare -ig dontCompressCudaFatbin=${dontCompressCudaFatbin:-0}
declare -ig dontNvccFixHookOrder=${dontNvccFixHookOrder:-0}

# NOTE: `appendToVar` does not export the variable to the environment because it is assumed to be a shell
# variable. To avoid variables being locally scoped, we must export it prior to adding values.
export NVCC_PREPEND_FLAGS="${NVCC_PREPEND_FLAGS:-}"
export NVCC_APPEND_FLAGS="${NVCC_APPEND_FLAGS:-}"

preConfigureHooks+=(nvccSetupEnvironmentVariables)
nixLog "added nvccSetupEnvironmentVariables to preConfigureHooks"

preConfigureHooks+=(nvccSetupCMakeEnvironmentVariables)
nixLog "added nvccSetupCMakeEnvironmentVariables to preConfigureHooks"

# If the host compiler does not match the stdenv compiler, we need to prevent NVCC from leaking the host compiler
# into the build.
if ! ((nvccHostCCMatchesStdenvCC)); then
  declare -ag nvccForbiddenHostCompilerRunpathEntries=(
    # Compiler libraries
    "@unwrappedCCRoot@/lib"
    "@unwrappedCCRoot@/lib64"
    "@unwrappedCCRoot@/gcc/@hostPlatformConfig@/@ccVersion@"
    # Compiler library
    "@unwrappedCCLibRoot@/lib"
  )

  # Add to prePhases to ensure all setup hooks are sourced prior to running the order check.
  prePhases+=(nvccHookOrderCheckPhase)
  nixLog "added nvccHookOrderCheckPhase to prePhases"

  # Tell CMake to ignore libraries provided by NVCC's host compiler when linking.
  preConfigureHooks+=(nvccSetupCMakeHostCompilerLeakPrevention)
  nixLog "added nvccSetupCMakeHostCompilerLeakPrevention to preConfigureHooks"

  # Ensure that the host compiler's libraries are not present in the runpath of the compiled binaries.
  postFixupHooks+=("autoFixElfFiles nvccRunpathCheck")
  nixLog "added 'autoFixElfFiles nvccRunpathCheck' to postFixupHooks"
fi

nvccHookOrderCheck() {
  # Ensure that our setup hook runs after autoPatchelf.
  # NOTE: Brittle because it relies on the name of the hook not changing.
  if ! occursOnlyOrAfterInArray "autoFixElfFiles nvccRunpathCheck" autoPatchelfPostFixup postFixupHooks; then
    nixErrorLog "autoPatchelfPostFixup must run before 'autoFixElfFiles nvccRunpathCheck'"
    return 1
  fi
  return 0
}

nvccFixHookOrder() {
  nixErrorLog "attempting to fix the hook order"
  local -a newPostFixupHooks=()
  # We know that:
  # 1. autoPatchelfPostFixup is in postFixupHooks.
  # 2. 'autoFixElfFiles nvccRunpathCheck' is in postFixupHooks and occurs only once because we guard
  #     against it being added multiple times.
  # 3. 'autoFixElfFiles nvccRunpathCheck' occurs before autoPatchelfPostFixup.
  # We assume that autoPatchelfPostFixup occurs only once.
  for hook in "${postFixupHooks[@]}"; do
    if [[ $hook == "autoFixElfFiles nvccRunpathCheck" ]]; then
      nixErrorLog "removing 'autoFixElfFiles nvccRunpathCheck'"
      continue
    fi

    nixErrorLog "keeping $hook"
    newPostFixupHooks+=("$hook")

    if [[ $hook == "autoPatchelfPostFixup" ]]; then
      nixErrorLog "adding 'autoFixElfFiles nvccRunpathCheck'"
      newPostFixupHooks+=("autoFixElfFiles nvccRunpathCheck")
    fi
  done
  postFixupHooks=("${newPostFixupHooks[@]}")

  # Run the check again to ensure the fix worked.
  if nvccHookOrderCheck; then
    nixErrorLog "fixed the hook order; this is a workaround, please fix the hook order in the package definition!"
    return 0
  else
    nixErrorLog "failed to fix the hook order"
    exit 1
  fi
}

nvccHookOrderCheckPhase() {
  if nvccHookOrderCheck; then
    return 0
  elif ((dontNvccFixHookOrder)); then
    exit 1
  else
    nvccFixHookOrder && return 0
  fi
}

nvccSetupEnvironmentVariables() {
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
  if ! ((dontCompressCudaFatbin)); then
    appendToVar NVCC_PREPEND_FLAGS "-Xfatbin=-compress-all"
    nixLog "appended -Xfatbin=-compress-all to NVCC_PREPEND_FLAGS"
  fi

  return 0
}

nvccSetupCMakeEnvironmentVariables() {
  # If CMake is not present, skip setting CMake flags.
  if ! command -v cmake &>/dev/null; then
    return 0
  fi

  # NOTE: Historically, we would set the following flags:
  # -DCUDA_HOST_COMPILER=@ccFullPath@
  # -DCMAKE_CUDA_HOST_COMPILER=@ccFullPath@
  # However, as of CMake 3.13, if CUDAHOSTCXX is set, CMake will automatically use it as the host compiler for CUDA.
  # Since we set CUDAHOSTCXX in cudaSetupEnvironmentVariables, we don't need to set these flags anymore.

  # Set CUDAHOSTCXX if unset or null
  # https://cmake.org/cmake/help/latest/envvar/CUDAHOSTCXX.html
  if [[ -z ${CUDAHOSTCXX:-} ]]; then
    export CUDAHOSTCXX="@ccFullPath@"
    nixLog "set CUDAHOSTCXX to $CUDAHOSTCXX"
  fi

  # TODO: Setting cudaArchs means that we have to recompile a large number of packages because `cuda_nvcc`
  # propagates this hook, and so the input derivations change.
  # Set CUDAARCHS if unset or null
  # https://cmake.org/cmake/help/latest/envvar/CUDAARCHS.html
  # if [[ -z ${CUDAARCHS:-} ]]; then
  #   export CUDAARCHS="@cudaArchs@"
  #   nixLog "set CUDAARCHS to $CUDAARCHS"
  # fi

  return 0
}

nvccSetupCMakeHostCompilerLeakPrevention() {
  # Instruct CMake to ignore libraries provided by NVCC's host compiler when linking, as these should be supplied by
  # the stdenv's compiler.
  for forbiddenEntry in "${nvccForbiddenHostCompilerRunpathEntries[@]}"; do
    addToSearchPathWithCustomDelimiter ";" CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES_EXCLUDE "$forbiddenEntry"
    nixLog "appended $forbiddenEntry to CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES_EXCLUDE"
  done
  return 0
}

nvccRunpathCheck() {
  if (($# == 0)); then
    nixErrorLog "no path provided"
    exit 1
  elif (($# > 1)); then
    nixErrorLog "expected exactly one path"
    exit 1
  elif [[ -z ${1:-} ]]; then
    nixErrorLog "empty path"
    exit 1
  fi

  local -r path="$1"
  local -r rpath="$(patchelf --print-rpath "$path")"

  local -a rpathEntries
  # shellcheck disable=SC2034
  # rpathEntries is used in computeFrequencyMap
  mapfile -d ":" -t rpathEntries < <(echo -n "$rpath")

  local -A rpathEntryOccurrences
  computeFrequencyMap rpathEntries rpathEntryOccurrences

  # NOTE: We do not automatically patch out the offending entry because it is typically a sign of a larger issue.
  local -i hasForbiddenEntry=0
  for forbiddenEntry in "${nvccForbiddenHostCompilerRunpathEntries[@]}"; do
    if ((rpathEntryOccurrences["$forbiddenEntry"])); then
      nixErrorLog "forbidden path $forbiddenEntry exists in run path of $path: $rpath"
      hasForbiddenEntry=1
    fi
  done

  ((hasForbiddenEntry)) && exit 1 || return 0
}
