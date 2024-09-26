# `cuda-redist`

## Roadmap

- \[ \] Improve dependency resolution by being less strict with versions.
- \[ \] Further documentation.
- \[ \] Test cases.

## Overview

This package provides library functions which help maintain the CUDA redistributable packages in Nixpkgs. It is meant to be used as part of the process of updating the manifests or supported CUDA versions in Nixpkgs. It is not meant to be used directly by users.

## Usage

To update every supported redist:

```bash
nix build .
for redist_name in $(ls ./redist/data/nvidia); do
  [[ "$redist_name" == "README.md" ]] && continue
  ./result/bin/update-nvidia-index --redist-name "$redist_name" --version all
  ./result/bin/get-nvidia-versions --redist-name "$redist_name" | xargs -P8 -I{} bash -c "./result/bin/update-custom-index --redist-name '$redist_name' --version {}"
done
```
