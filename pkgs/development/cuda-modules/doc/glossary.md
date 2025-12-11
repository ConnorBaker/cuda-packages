# Glossary

[Return to index.](../README.md)

## Terminology

- Compute capability (CC):

    This is the architecture of, and thus features supported by, a given NVIDIA GPU's hardware.
    Refer to [NVIDIA's CUDA GPU Compute Capability table](https://developer.nvidia.com/cuda-gpus)
    or [this table on Wikipedia](https://en.wikipedia.org/wiki/CUDA#GPUs_supported) to find the CC of a given GPU.

    Generally, each major CC version corresponds to a major GPU architecture revision (e.g. Maxwell = CC 5.x, Pascal = CC 6.x, Volta = CC 7.x).

    Also known as a device's "SM version".
    Not to be confused with the CUDA software platform version.

    Reference: https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#compute-capability

- (CUDA) binary code:

    This is the actual binary code that is executed by the GPU.

    It is compute capability (CC) specific.
    Binary code generated for a given CC may run on later minor CC versions.
    It may not run on previous minor CC versions or any other major CC version.

    Note: this term may be overloaded.
    You may be familiar with the concept of a non-CUDA compilers producing what is traditionally known as a "binary object".
    NVCC can produce a traditional "binary object" which does not contain CUDA binary code (and instead only contains CUDA PTX code, see below).
    Outside of this note, this FAQ will only use the term "binary" to refer to "CUDA binary code", and will refer to a traditional "binary object" as simply an "object".

    Reference: https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#binary-compatibility

- PTX code:

    This is an intermediate language produced by NVCC and embedded into its produced output object.
    It is compiled at runtime by the CUDA driver when loaded, allowing for targeting
    of multiple CUDA architectures at the expense of some additional startup cost.

    PTX code generated for a given compute capability (CC) can not run on previous CC versions.
    However, unlike CUDA binary code, it can run on all later CC versions, including versions not yet released.
    (Note that the PTX code will not be able to utilize features from later CC versions.)

    Thus, to generate code for a variety of CC targets, with forward and backward compatibility,
    a packager can choose to generate binary code to support all previous major CC versions,
    along with PTX code for the current (and implicitly future) major CC versions.
    In CMake 3.23+, this can be done simply by setting `-DCMAKE_CUDA_ARCHITECTURES=all-major`.

    Reference: https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#ptx-compatibility

- real architecture:

    When CUDA code is being compiled to binary, this is the compute capability it is targeting.

- virtual architecture:

    When CUDA code is being compiled to PTX, this is the compute capability it is targeting.

- CUDA package set:
- extension:
