# cuda-packages

Out of tree (Nixpkgs) experiments with packaging CUDA in an extensible way.

Most code lives in Nixpkgs and is copied/modified here for ease of development.

## Notes

- CUDA 12.3 is missing `cuda_compat` and so will not work on the Jetsons
- CUDNN via redist is only available for Jetsons on CUDA 12
  - Will have to re-package Debian release of CUDNN for CUDA 11
- TensorRT via redist (10.x) is only available for Orin
  - Will have to re-package Debian release of TensorRT (pre-10.x) for Xavier
