# shellcheck shell=bash

setUccConfigFile() {
  ((NIX_DEBUG >= 1)) && echo "setUccConfigFile: setting UCC_CONFIG_FILE" >&2

  # The UCC_CONFIG_FILE environment variable is used by the UCC library to locate the configuration file. The default
  # location is share/ucc.conf, one level above the location `libcal`'s shared libraries are installed. We need to set
  # this environment variable to the output which actually holds the configuration file -- `out`.
  export UCC_CONFIG_FILE="@out@/share/ucc.conf"

  # The return code of the function is the return code of the last command executed. Since NIX_DEBUG typically isn't
  # set, the return value of the last command is 1 (false), causing the setup hook to abort. We don't want that, so
  # we explicitly return 0.
  return 0
}

guardSetUccConfigFile() {
  # Allow the user to disable the addition of CUDA libraries, specifically
  declare -ig cudaDontSetUccConfigFile=${cudaDontSetUccConfigFile:-0}
  declare -ig NIX_DEBUG=${NIX_DEBUG:-0}

  local guard="Sourcing"
  local reason=" from @out@/nix-support/setup-hook"

  ((cudaDontSetUccConfigFile == 1)) &&
    guard=Skipping &&
    reason="$reason (because we've been told not to set UCC_CONFIG_FILE)"

  echo "$guard setUccConfigFile$reason" >&2

  [[ $guard == Sourcing ]] || return 0

  setUccConfigFile
}
guardSetUccConfigFile
