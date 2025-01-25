# shellcheck shell=bash

# Only run the hook from nativeBuildInputs
if ((${hostOffset:?} == -1 && ${targetOffset:?} == 0)); then
  # shellcheck disable=SC1091
  source @nixLogWithLevelAndFunctionNameHook@
  nixLog "sourcing cuda-runpath-fixup-setup-hook.sh"
else
  return 0
fi

if (("${cudaRunpathFixupSetupHookOnce:-0}" > 0)); then
  nixWarnLog "skipping because the hook has been propagated more than once"
  return 0
fi

declare -ig cudaRunpathFixupSetupHookOnce=1

postFixupHooks+=("cudaRunpathAssertHookOrder")
nixLog "added cudaRunpathAssertHookOrder to postFixupHooks"

cudaRunpathAssertHookOrder() {
  # Ensure that our setup hook runs after autoPatchelf.
  local -i autoPatchelfSeen=0
  local -i cudaRunpathFixupSeen=0

  for hook in "${postFixupHooks[@]}"; do
    case "$hook" in
    # TODO(@connorbaker): This is fragile because it relies on the implementation detail of autoPatchelf's setup
    # hook being the same.
    "autoPatchelfPostFixup")
      if ((autoPatchelfSeen > 0)); then
        nixErrorLog "have seen autoPatchelfPostFixup multiple times in postFixupHooks"
      fi
      if ((cudaRunpathFixupSeen > 0)); then
        nixErrorLog "autoPatchelfPostFixup cannot follow cudaRunpathFixupSetupHook"
        exit 1
      fi
      autoPatchelfSeen+=1
      ;;
    "autoFixElfFiles cudaRunpathFixup")
      if ((cudaRunpathFixupSeen > 0)); then
        nixErrorLog "have seen cudaRunpathFixupSetupHook multiple times in postFixupHooks"
      fi
      cudaRunpathFixupSeen+=1
      ;;
    *) continue ;;
    esac
  done
}

postFixupHooks+=("autoFixElfFiles cudaRunpathFixup")
nixLog "added 'autoFixElfFiles cudaRunpathFixup' to postFixupHooks"

cudaRunpathFixup() {
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

  # The cudaCompatDir should appear before any other if not empty (that is, when it is available/desired).
  # TODO(@connorbaker): The cudaStubDir should be replaced with the driverDir (stubs are only for linking).
  local -r cudaCompatDir="@cudaCompatDir@"
  local -r cudaStubDir="@cudaStubDir@"
  local -r driverDir="@driverDir@"

  local path="$1"
  local rpathEntry
  local newRpath

  # shellcheck disable=SC2155
  local origRpath="$(patchelf --print-rpath "$path")"
  local -a origRpathEntries
  mapfile -d ":" -t origRpathEntries <<<"$origRpath"

  local -A rpathObserved=()
  local -a newRpathEntries=()

  for rpathEntry in "${origRpathEntries[@]}"; do
    if [[ -n $cudaCompatDir && $rpathEntry == "$cudaCompatDir"* ]]; then
      if [[ $rpathEntry != "$cudaCompatDir" ]]; then
        nixErrorLog "observed incorrect cudaCompatDir ($cudaCompatDir vs $rpathEntry) in run path of $path: $origRpath"
        exit 1
      elif [[ -v rpathObserved["$cudaStubDir"] || -v rpathObserved["$driverDir"] ]]; then
        nixErrorLog "observed cudaStubDir or driverDir before cudaCompatDir in run path of $path"
        exit 1
      fi
    elif [[ $rpathEntry == "$cudaStubDir"* ]]; then
      if [[ $rpathEntry != "$cudaStubDir" ]]; then
        nixErrorLog "observed incorrect cudaStubDir in run path of $path"
        exit 1
      elif [[ -n $cudaCompatDir && ! -v rpathObserved["$cudaCompatDir"] ]]; then
        nixErrorLog "observed cudaStubDir or driverDir before cudaCompatDir in run path of $path"
        exit 1
      fi

      # Set rpathEntry to driverDir since we don't want to load the stubs
      nixInfoLog "replacing $rpathEntry with $driverDir"
      rpathEntry="$driverDir"
    elif [[ $rpathEntry == "$driverDir"* ]]; then
      if [[ $rpathEntry != "$driverDir" ]]; then
        nixErrorLog "observed incorrect driverDir in run path of $path"
        exit 1
      elif [[ -n $cudaCompatDir && ! -v rpathObserved["$cudaCompatDir"] ]]; then
        nixErrorLog "observed cudaStubDir or driverDir before cudaCompatDir in run path of $path"
        exit 1
      fi
    fi

    if [[ -v rpathObserved["$rpathEntry"] ]]; then
      nixErrorLog "observed $rpathEntry multiple times in run path of $path"
    else
      rpathObserved["$rpathEntry"]=1
      newRpathEntries+=("$rpathEntry")
    fi
  done

  newRpath="$(concatStringsSep ":" newRpathEntries)"

  if [[ $origRpath != "$newRpath" ]]; then
    nixLog "replacing $origRpath with $newRpath"
    patchelf --set-rpath "$newRpath" "$path"
  fi

  return 0
}
