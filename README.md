# cuda-packages

Out of tree (Nixpkgs) experiments with packaging CUDA in an extensible way.

Most code lives in Nixpkgs and is copied/modified here for ease of development.

## Notes

- Keeping only CUDA 11.8 and latest release of CUDA 12 (so long as it supports most of the CUDA ecosystem)
- Consider CUDA 11.8 EOL
- Python wrappers which invoke CMake _do not always pass their environment_ to the CMake process. That means a number of the environment variables we set so CMake's auto-detection functionality just works is broken.
- Derivations in our package set should use `strictDeps=true` and `__structuredAttrs=true` _by default_, unless they have a good reason not to (e.g., Python packaging has not been updated yet to support structured attributes: <https://github.com/NixOS/nixpkgs/pull/347194>).
