# shellcheck shell=bash

# Guard against double inclusion.
if (("${nixLogWithLevelAndFunctionNameInstalled:-0}" > 0)); then
  nixInfoLog "skipping because the hook has been propagated more than once"
  return 0
fi
declare -ig nixLogWithLevelAndFunctionNameInstalled=1

nixLog() {
  # Return a value explicitly instead of the implicit return of the last command (result of the test).
  [[ -z ${NIX_LOG_FD-} ]] && return 0

  # Use the function name of the caller, unless it is _callImplicitHook, in which case use the name of the hook.
  local callerName="${FUNCNAME[1]}"
  if [[ $callerName == "_callImplicitHook" ]]; then
    callerName="${hookName:?}"
  fi
  printf "%s: %s\n" "$callerName" "$*" >&"$NIX_LOG_FD"
}

nixLogWithLevel() {
  # Return a value explicitly instead of the implicit return of the last command (result of the test).
  [[ -z ${NIX_LOG_FD-} || ${NIX_DEBUG:-0} -lt ${1:?} ]] && return 0

  local logLevel
  case "${1:?}" in
  0) logLevel=ERROR ;;
  1) logLevel=WARN ;;
  2) logLevel=NOTICE ;;
  3) logLevel=INFO ;;
  4) logLevel=TALKATIVE ;;
  5) logLevel=CHATTY ;;
  6) logLevel=DEBUG ;;
  7) logLevel=VOMIT ;;
  *)
    echo "Invalid log level: ${1:?}" >&2
    return 1
    ;;
  esac

  # Use the function name of the caller, unless it is _callImplicitHook, in which case use the name of the hook.
  local callerName="${FUNCNAME[2]}"
  if [[ $callerName == "_callImplicitHook" ]]; then
    callerName="${hookName:?}"
  fi

  # Use the function name of the caller's caller, since we should only every be invoked by nix*Log functions.
  printf "%s: %s: %s\n" "$logLevel" "$callerName" "${2:?}" >&"$NIX_LOG_FD"
}

nixErrorLog() {
  nixLogWithLevel 0 "$*"
}

nixWarnLog() {
  nixLogWithLevel 1 "$*"
}

nixNoticeLog() {
  nixLogWithLevel 2 "$*"
}

nixInfoLog() {
  nixLogWithLevel 3 "$*"
}

nixTalkativeLog() {
  nixLogWithLevel 4 "$*"
}

nixChattyLog() {
  nixLogWithLevel 5 "$*"
}

nixDebugLog() {
  nixLogWithLevel 6 "$*"
}

nixVomitLog() {
  nixLogWithLevel 7 "$*"
}

nixLog "installed nix loggers with level and function name functionality"
