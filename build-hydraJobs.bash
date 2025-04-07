#!/usr/bin/env bash

if (($# != 1)); then
  echo "Usage: $0 <flake ref>"
  exit 1
fi

nix-eval-jobs --flake "$1" --force-recurse --constituents |
  jq -cr '.constituents + [.drvPath] | .[] | select(.!=null) + "^*"' |
  nom build --keep-going --no-link --print-out-paths --stdin
