{
  /**
    A list of redistributable architectures to use in creation of the redistArch type.

    # Type

    ```
    redistArches :: List String
    ```
  */
  redistArches = [
    "linux-aarch64"
    "linux-ppc64le"
    "linux-sbsa"
    "linux-x86_64"
    "source" # Source-agnostic platform
  ];

  /**
    A list of redistributable names to use in creation of the redistName type.

    # Type

    ```
    redistNames :: List String
    ```
  */
  redistNames = [
    "cublasmp"
    "cuda"
    "cudnn"
    "cudss"
    "cuquantum"
    "cusolvermp"
    "cusparselt"
    "cutensor"
    "nppplus"
    # "nvidia-driver",  # NOTE: Some of the earlier manifests don't follow our scheme.
    "nvjpeg2000"
    "nvpl"
    "nvtiff"
    "tensorrt" # NOTE: not truly a redist; uses different naming convention
  ];

  /**
    The prefix of the URL for redistributable files.

    # Type

    ```
    redistUrlPrefix :: String
    ```
  */
  redistUrlPrefix = "https://developer.download.nvidia.com/compute";
}
