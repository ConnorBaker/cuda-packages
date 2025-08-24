# cuda-packages

Out of tree (Nixpkgs) experiments with packaging CUDA in an extensible way.

> [!IMPORTANT]
>
> I am in the process of upstreaming this into Nixpkgs. This repository will be archived once that is complete.

Most code lives in Nixpkgs and is copied/modified here for ease of development.

## Notes

- Python wrappers which invoke CMake _do not always pass their environment_ to the CMake process. That means a number of the environment variables we set so CMake's auto-detection functionality just works is broken.
- `autoAddDriverRunpath` for CMake projects is a crutch -- the correct fix is to have the CMake project link against `CUDA::cudart`.
- `12.2.2` is kept around because it is the last version of CUDA 12 supported by Xavier through `cuda_compat`
  - _DO NOT_ rely on it being around forever -- try to upgrade to newer hardware!
- `cuda_compat` can be disabled by setting the package to `null`. This is useful in cases where the host OS has a recent enough CUDA driver that the compatibility library isn't needed.
- `nvprune` can only be run on relocatable libraries, so it wouldn't be helpful as a hook because NVIDIA's dynamic libraries are not relocatable, and we generally don't use the static libraries.

## Todo

- Packages with `stubs` outputs should have a hook for the stub output which replaces RPATH entries pointing to the stub with driverLink or cuda_compat, where appropriate
- Discovered in the process of examining `saxpy`'s build, using `declare NIX_DEBUG=4` and `export NIX_DEBUG=4` yield different logs and results!
  - Only `export` shows the before and after flags used with toolchain invocations -- `declare` does not!
  - Only `declare` yields an output with the same RUNPATH as the original -- with `export`, entries are missing!
- think about creating `noRunpathAmbiguityHook` -- a runpath is considered "ambiguous" if it has multiple paths to the same library name
  - This is a sign that the package is linking against the same library multiple times (different versions?), which might be a source of undefined behavior depending on the order paths are resolved
- `cuda_compat` should only be used when the host driver is not equal to the version of the CUDA package set currently being used.
  - Would detecting that would be impure?
- Update `modules/cuda-capability-to-info.nix` for Jetson devices (i.e., Xavier and Orin on JetPack 5 max out at 12.2 with `cuda_compat`)
  - This would require knowing what the host driver version is, which is impure
- Figure out why separable compilation isn't working.
- Additional packages:
  - https://developer.download.nvidia.com/compute/redist/nvshmem/
  - https://developer.download.nvidia.com/compute/nvidia-hpc-benchmarks/redist/
  - https://developer.nvidia.com/nvidia-hpc-sdk-249-downloads
  - https://github.com/NVIDIA/gdrcopy
  - https://github.com/NVIDIA/nvImageCodec
  - https://developer.download.nvidia.com/compute/nvidia-driver/redist/ (for use with nixGL?)
