#!/usr/bin/env bash

nix-eval-jobs --flake .#hydraJobs.x86_64-linux --force-recurse --constituents |
  jq -cr '.constituents + [.drvPath] | .[] + "^*"' |
  nom build --keep-going --no-link --print-out-paths --stdin
