# Updating

[Return to index.](../README.md)

Generally, there are three steps to updating CUDA packages in Nixpkgs:

1. Updating the CUDA redistributables and creating a new package set, as needed.
2. Updating the Nix expressions containing information about supported compilers and GPUs.
3. Testing the updated package set(s) to ensure release-critical packages are still working.

## Updating CUDA redistributables

See the `README` in the `pkgs/development/cuda-modules/manifests` directory corresponding to the redistributable you wish to update for more information specific to that redistributable, including the location of its manifests.

In general, there are three steps to updating CUDA redistributables:

1. Download the new manifest from NVIDIA and place it in the appropriate directory in `pkgs/development/cuda-modules/manifests`.
2. Update the corresponding entries in `pkgs/development/cuda-modules/fixups`, as needed.
3. Update the `manifests` and `fixups` arguments provided to `callPackage` in `pkgs/top-level/cuda-packages.nix` which create the CUDA package sets.

If the redistributable is `cuda` and the update includes a minor version bump, you will also need to create a new `callPackage` invocation in `pkgs/top-level/cuda-packages.nix` for the new package set. This is not necessary for patch releases.

## Updating supported compilers and GPUs

1. Update the `nvccCompatibilities` attribute set in `pkgs/development/cuda-modules/lib/data.nix` to include the newest release of NVCC, as well as any newly supported host compilers.
2. Update the `cudaCapabilityToInfo` attribute set in `pkgs/development/cuda-modules/lib/data.nix` to include any new GPUs supported by the new release of CUDA.

## Testing package sets

TODO(@connorbaker): Describe core set of packages which should remain working and the tests we can run to verify they work.
