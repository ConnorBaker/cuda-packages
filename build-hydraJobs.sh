#!/usr/bin/env bash

PREFIX="$PWD#hydraJobs.x86_64-linux"
nix eval --json "$PREFIX" |
  jq --arg prefix "$PREFIX" -cr 'paths(strings) | join(".") | $prefix + "." + .' |
  nom build --keep-going --no-link --print-out-paths --stdin
