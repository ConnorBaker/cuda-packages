# CMake

[Return to index.](../../README.md)

[Return to Digressions.](./README.md)

## First-class CMake CUDA support

CMake's support for CUDA as a language is relatively new; established ecosystems like OpenCV, ONNX, and PyTorch have for years maintained their own CMake modules to find and configure CUDA packages for use with CMake. For a number of reasons, be they backwards-compatibility requirements preventing adopting newer versions of CMake or lack of time to perform such a migration, leveraging CMake's first-class support for CUDA remains out of grasp.

Concretely, each ecosystem was, and for the foreseeable future will continue to be, a special kind of CMake hell, replete with wildly different approaches to finding, using, and enforcing invariants on CUDA packages. A recurring pain point in packaging some CUDA-enabled projects is their insistence that all CUDA packages be installed in a single directory, which is incompatible with the CUDA package set's use of multiple outputs.
