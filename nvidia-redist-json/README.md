# nvidia-redist-json

NVIDIA manifests or in the case of TensorRT, a manifest meant to conform to NVIDIA's manifest format.

Version policy:

- CUDA 11.8 is supported, but is end of life; packages should move off of it and to CUDA 12.
- The latest release of CUDA 12 is supported, so long as key packages can be built (or patched to build) against it.

In general, only the latest version of each manifest is retained, unless support for an architecture is dropped, in which case the last version supporting that architecture is retained.
