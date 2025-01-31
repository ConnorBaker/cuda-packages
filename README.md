# cuda-packages

Out of tree (Nixpkgs) experiments with packaging CUDA in an extensible way.

Most code lives in Nixpkgs and is copied/modified here for ease of development.

Top-level:

- `cudaConfig`: evaluated configuration for CUDA package sets
  - includes `hostNixSystem`, `hostRedistArch`, and `cudaCapabilities` (among others), which are helpful when writing modules for `cudaModules` with the goal of conditionally changing the build based on what's being targeted through `mkMerge` and `mkIf`.
- `cudaPackagesExtensions`: extensions (overlays) applied to each CUDA package set
  - an easy way to add packages to all CUDA package sets
- `cudaModules`: modules which change the creation of CUDA package sets
  - an easy way to add new CUDA package sets, change the defaults, or add packages to a specific CUDA package set

## Notes

- Python wrappers which invoke CMake _do not always pass their environment_ to the CMake process. That means a number of the environment variables we set so CMake's auto-detection functionality just works is broken.
- `autoAddDriverRunpath` for CMake projects is a crutch -- the correct fix is to have the CMake project link against `CUDA::cudart`.
- `cudaPackages.callPackage` sets `strictDeps=true` and `__structuredAttrs=true` _by default_. Packages must have a good reason to opt out (e.g., Python packaging has not been updated yet to support structured attributes: <https://github.com/NixOS/nixpkgs/pull/347194>).
- `cudaPackages.callPackage` uses a name prefix for more descriptive store path names.
  - Prefix is available as `cudaPackages.cudaNamePrefix`.
- Manifests and overrides are versioned
  - This prevents conflicts when downstream consumers add their own manifests and overrides.
- `noBrokenSymlinksHook` checks for broken or reflexive symlinks in your outputs, which are usually a sign of packaging gone wrong
- `12.2.2` is kept around because it is the last version of CUDA 12 supported by Xavier through `cuda_compat`
  - _DO NOT_ rely on it being around forever -- try to upgrade to newer hardware!
- `cuda_compat` can be disabled by setting the package to `null`. This is useful in cases where the host OS has a recent enough CUDA driver that the compatibility library isn't needed.

## Todo

- docs/tests for `arrayUtilitiesHook`
- docs for `deduplicateRunpathEntriesHook`
- docs/tests for CUDA hooks using `arrayUtilitiesHook`
- think about creating `noRunpathAmbiguityHook` -- a runpath is considered "ambiguous" if it has multiple paths to the same library name
  - This is a sign that the package is linking against the same library multiple times (different versions?), which might be a source of undefined behavior depending on the order paths are resolved
- `cuda_compat` should only be used when the host driver is not equal to the version of the CUDA package set currently being used.
  - Would detecting that would be impure?
- When requested capability is newer than what is supported by version of CUDA, emit PTX for forward compat?
- Update `modules/gpus.nix` for Jetson devices (i.e., Xavier and Orin on JetPack 5 max out at 12.2 with `cuda_compat`)
  - This would require knowing what the host driver version is, which is impure
- Allow devices to be in `pkgsCuda` if at least one CUDA package set version supports them?
  - Hide the other releases?
- A bunch of stuff (including docs)
- Throw if trying to build for a capability newer than the CUDA package set can support.
- Figure out why separable compilation isn't working.
- Packages:
  - https://developer.download.nvidia.com/compute/nvcomp/redist/
  - https://developer.download.nvidia.com/compute/redist/nvshmem/
  - https://developer.download.nvidia.com/compute/nvidia-hpc-benchmarks/redist/
  - https://developer.nvidia.com/nvidia-hpc-sdk-249-downloads
  - https://github.com/NVIDIA/gdrcopy
  - https://github.com/NVIDIA/nvImageCodec
  - https://developer.download.nvidia.com/compute/nvidia-driver/redist/ (for use with nixGL?)
