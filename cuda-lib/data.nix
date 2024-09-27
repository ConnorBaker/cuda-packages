{
  /**
    A list of platforms to use in creation of the platform type.

    # Type

    ```
    platforms :: List String
    ```
  */
  platforms = [
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
    # "nvidia-driver",  # NOTE: Some of the earlier manifests don't follow our scheme.
    "nvjpeg2000"
    "nvpl"
    "nvtiff"
    "tensorrt" # NOTE: not truly a redist; uses different naming convention
  ];

  /**
    The prefix of the URL for redistributable files

    # Type

    ```
    redistUrlPrefix :: String
    ```
  */
  redistUrlPrefix = "https://developer.download.nvidia.com/compute";
}
