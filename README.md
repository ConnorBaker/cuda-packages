# cuda-packages

Out of tree (Nixpkgs) experiments with packaging CUDA in an extensible way.

Most code lives in Nixpkgs and is copied/modified here for ease of development.

## Notes

- Keeping only CUDA 11.8 and latest release of CUDA 12 (so long as it supports most of the CUDA ecosystem)
- Consider CUDA 11.8 EOL
- Python wrappers which invoke CMake _do not always pass their environment_ to the CMake process. That means a number of the environment variables we set so CMake's auto-detection functionality just works is broken.
- `autoAddDriverRunpath` for CMake projects is a crutch -- the correct fix is to have the CMake project link against `CUDA::cudart`.
- `cudaStdenv` sets `strictDeps=true` and `__structuredAttrs=true` _by default_. Packages must have a good reason to opt out (e.g., Python packaging has not been updated yet to support structured attributes: <https://github.com/NixOS/nixpkgs/pull/347194>).
- `cudaStdenv` uses a name prefix for more descriptive store path names.
  - Prefix is available as `backendStdenv.cudaNamePrefix`.

## Todo

- Allow multiple versions of non-cuda-redist packages (e.g., CUDNN) to be installed at once?
- Manifests and overrides are versioned
  - This prevents conflicts when downstream consumers add their own manifests and overrides.
- A bunch of stuff (including docs)
- Update the setup hooks to use the logging functionality introduced in newer versions of Nixpkgs's `setup.sh`.
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
