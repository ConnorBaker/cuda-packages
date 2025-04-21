# Updating

[Return to index.](../README.md)

## Adding a new CUDA release

> [!WARNING]
>
> This section of the docs is still very much in progress. Feedback is welcome in GitHub Issues tagging @NixOS/cuda-maintainers or on [Matrix](https://matrix.to/#/#cuda:nixos.org).

The CUDA Toolkit is a suite of CUDA libraries and software meant to provide a development environment for CUDA-accelerated applications. Until the release of CUDA 11.4, NVIDIA had only made the CUDA Toolkit available as a multi-gigabyte runfile installer, which we provide through the [`cudaPackages.cudatoolkit`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages.cudatoolkit) attribute. From CUDA 11.4 and onwards, NVIDIA has also provided CUDA redistributables (“CUDA-redist”): individually packaged CUDA Toolkit components meant to facilitate redistribution and inclusion in downstream projects. These packages are available in the [`cudaPackages`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages) package set.

All new projects should use the CUDA redistributables available in [`cudaPackages`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages) in place of [`cudaPackages.cudatoolkit`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages.cudatoolkit), as they are much easier to maintain and update.

### Updating CUDA redistributables

See the `README` in the `pkgs/development/cuda-modules/manifests` directory corresponding to the redistributable you wish to update for more information specific to that redistributable, including the location of its manifests.

In general, there are three steps to updating CUDA redistributables:

1. Download the new manifest from NVIDIA and place it in the appropriate directory in `pkgs/development/cuda-modules/manifests`.
2. Update the corresponding entries in `pkgs/development/cuda-modules/fixups`, as needed.
3. Update the `manifests` and `fixups` arguments provided to `callPackage` in `pkgs/top-level/cuda-packages.nix` which create the CUDA package sets.

If the redistributable is `cuda` and the update includes a minor version bump, you will also need to create a new `callPackage` invocation in `pkgs/top-level/cuda-packages.nix` for the new package set. This is not necessary for patch releases.

### Updating supported compilers and GPUs

1. Update the `nvccCompatibilities` attribute set in `pkgs/development/cuda-modules/lib/data.nix` to include the newest release of NVCC, as well as any newly supported host compilers.
2. Update the `cudaCapabilityToInfo` attribute set in `pkgs/development/cuda-modules/lib/data.nix` to include any new GPUs supported by the new release of CUDA.
