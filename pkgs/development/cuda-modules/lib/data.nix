{ cudaLib, lib }:
{
  /**
    The path to the CUDA packages root directory, for use with `callPackage` to create new package sets.

    # Type

    ```
    cudaPackagesPath :: Path
    ```
  */
  cudaPackagesPath = ./..;

  /**
    A list of redistributable systems to use in creation of the `redistSystem` option type.

    # Type

    ```
    redistSystems :: [String]
    ```
  */
  redistSystems = [
    "linux-aarch64"
    "linux-all" # Taken to mean all other linux systems
    "linux-sbsa"
    "linux-x86_64"
    "source" # Source-agnostic platform
  ];

  /**
    A list of redistributable names to use in creation of the `redistName` option type.

    # Type

    ```
    redistNames :: [String]
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
    "nvcomp"
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

  /**
    Attribute set of supported CUDA capability mapped to information about that capability.

    NOTE: Building with architecture-accelerated features (capabilities with an `a` suffix) is neither forward nor
    backwards compatible with the base architecture. For example, device code targeting `10.0a` will not work on a
    a device presenting as `10.0`, and vice versa.

    Many thanks to Arnon Shimoni for maintaining a list of these architectures and capabilities.
    Without your work, this would have been much more difficult.
    https://arnon.dk/matching-sm-architectures-arch-and-gencode-for-various-nvidia-cards/

    # Type

    ```
    cudaCapabilityToInfo ::
      Attrs
        CudaCapability
        { archName :: String
        , cudaCapability :: CudaCapability
        , isJetson :: Bool
        , isAccelerated :: Bool
        , minCudaMajorMinorVersion :: MajorMinorVersion
        , maxCudaMajorMinorVersion :: MajorMinorVersion
        , dontDefaultAfterCudaMajorMinorVersion :: Null | MajorMinorVersion
        }
    ```

    `archName`

    : The name of the microarchitecture

    `cudaCapability`

    : The CUDA capability

    `isJetson`

    : Whether this capability is part of NVIDIA's line of Jetson embedded computers. This field is notable
      because it tells us what architecture to build for (as Jetson devices are aarch64).
      More on Jetson devices here: https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/
      NOTE: These architectures are only built upon request.

    `isAccelerated`

    : Whether this capability is an accelerated version of a base architecture.
      This field is notable because it tells us what architecture to build for (as accelerated architectures are
      not forward or backward compatible with the base architecture).
      For example, device code targeting `10.0a` will not work on a device presenting as `10.0`, and vice versa.

    `minCudaMajorMinorVersion`

    : The minimum (inclusive) CUDA version that supports this capability.

    `maxCudaMajorMinorVersion`

    : The maximum (exclusive) CUDA version that supports this capability.
      `null` means there is no maximum.

    `dontDefaultAfterCudaMajorMinorVersion`

    : The CUDA version after which to exclude this capability from the list of default capabilities we build.
  */
  cudaCapabilityToInfo =
    lib.mapAttrs
      (
        cudaCapability:
        # Supplies default values.
        {
          archName,
          isJetson ? false,
          isAccelerated ? (lib.hasSuffix "a" cudaCapability),
          minCudaMajorMinorVersion,
          maxCudaMajorMinorVersion ? null,
          dontDefaultAfterCudaMajorMinorVersion ? null,
        }:
        {
          inherit
            archName
            cudaCapability
            isJetson
            isAccelerated
            minCudaMajorMinorVersion
            maxCudaMajorMinorVersion
            dontDefaultAfterCudaMajorMinorVersion
            ;
        }
      )
      {
        "5.0" = {
          # Tesla/Quadro M series
          archName = "Maxwell";
          minCudaMajorMinorVersion = "10.0";
          dontDefaultAfterCudaMajorMinorVersion = "11.0";
        };
        "5.2" = {
          # Quadro M6000 , GeForce 900, GTX-970, GTX-980, GTX Titan X
          archName = "Maxwell";
          minCudaMajorMinorVersion = "10.0";
          dontDefaultAfterCudaMajorMinorVersion = "11.0";
        };
        "6.0" = {
          # Quadro GP100, Tesla P100, DGX-1 (Generic Pascal)
          archName = "Pascal";
          minCudaMajorMinorVersion = "10.0";
        };
        "6.1" = {
          # GTX 1080, GTX 1070, GTX 1060, GTX 1050, GTX 1030 (GP108), GT 1010 (GP108) Titan Xp, Tesla
          # P40, Tesla P4, Discrete GPU on the NVIDIA Drive PX2
          archName = "Pascal";
          minCudaMajorMinorVersion = "10.0";
        };
        "7.0" = {
          # DGX-1 with Volta, Tesla V100, GTX 1180 (GV104), Titan V, Quadro GV100
          archName = "Volta";
          minCudaMajorMinorVersion = "10.0";
        };
        "7.2" = {
          # Jetson AGX Xavier, Drive AGX Pegasus, Xavier NX
          archName = "Volta";
          minCudaMajorMinorVersion = "10.0";
          # Note: without `cuda_compat`, maxCudaMajorMinorVersion is 11.8
          # https://docs.nvidia.com/cuda/cuda-for-tegra-appnote/index.html#deployment-considerations-for-cuda-upgrade-package
          maxCudaMajorMinorVersion = "12.2";
          isJetson = true;
        };
        "7.5" = {
          # GTX/RTX Turing – GTX 1660 Ti, RTX 2060, RTX 2070, RTX 2080, Titan RTX, Quadro RTX 4000,
          # Quadro RTX 5000, Quadro RTX 6000, Quadro RTX 8000, Quadro T1000/T2000, Tesla T4
          archName = "Turing";
          minCudaMajorMinorVersion = "10.0";
        };
        "8.0" = {
          # NVIDIA A100 (the name “Tesla” has been dropped – GA100), NVIDIA DGX-A100
          archName = "Ampere";
          minCudaMajorMinorVersion = "11.2";
        };
        "8.6" = {
          # Tesla GA10x cards, RTX Ampere – RTX 3080, GA102 – RTX 3090, RTX A2000, A3000, RTX A4000,
          # A5000, A6000, NVIDIA A40, GA106 – RTX 3060, GA104 – RTX 3070, GA107 – RTX 3050, RTX A10, RTX
          # A16, RTX A40, A2 Tensor Core GPU
          archName = "Ampere";
          minCudaMajorMinorVersion = "11.2";
        };
        "8.7" = {
          # Jetson AGX Orin and Drive AGX Orin only
          archName = "Ampere";
          minCudaMajorMinorVersion = "11.5";
          isJetson = true;
        };
        "8.9" = {
          # NVIDIA GeForce RTX 4090, RTX 4080, RTX 6000, Tesla L40
          archName = "Ada";
          minCudaMajorMinorVersion = "11.8";
        };
        "9.0" = {
          # NVIDIA H100 (GH100)
          archName = "Hopper";
          minCudaMajorMinorVersion = "11.8";
        };
        "9.0a" = {
          # NVIDIA H100 (GH100) Accelerated
          archName = "Hopper";
          minCudaMajorMinorVersion = "12.0";
        };
        "10.0" = {
          # NVIDIA B100
          archName = "Blackwell";
          minCudaMajorMinorVersion = "12.8";
        };
        "10.0a" = {
          # NVIDIA B100 Accelerated
          archName = "Blackwell";
          minCudaMajorMinorVersion = "12.8";
        };
        "10.1" = {
          # NVIDIA Blackwell
          archName = "Blackwell";
          minCudaMajorMinorVersion = "12.8";
        };
        "10.1a" = {
          # NVIDIA Blackwell Accelerated
          archName = "Blackwell";
          minCudaMajorMinorVersion = "12.8";
        };
        "12.0" = {
          # NVIDIA GeForce RTX 5090 (GB202), RTX 5080 (GB203), RTX 5070 (GB205)
          archName = "Blackwell";
          minCudaMajorMinorVersion = "12.8";
        };
        "12.0a" = {
          # NVIDIA Blackwell Accelerated
          archName = "Blackwell";
          minCudaMajorMinorVersion = "12.8";
        };
      };

  /**
    All CUDA capabilities, including accelerated and Jetson capabilities, sorted by version.

    # Type

    ```
    allSortedCudaCapabilities :: [CudaCapability]
    ```
  */
  allSortedCudaCapabilities = lib.sort lib.versionOlder (
    lib.attrNames cudaLib.data.cudaCapabilityToInfo
  );

  /**
    Mapping of CUDA micro-architecture name to capabilities belonging to that family.

    # Type

    ```
    cudaArchNameToCapabilities :: Attrs NonEmptyStr (NonEmptyListOf CudaCapability)
    ```
  */
  cudaArchNameToCapabilities = lib.groupBy (
    cudaCapability: cudaLib.data.cudaCapabilityToInfo.${cudaCapability}.archName
  ) cudaLib.data.cudaCapabilities;

  /**
    Mapping of CUDA versions to NVCC compatibilities

    Taken from
    https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#host-compiler-support-policy

      NVCC performs a version check on the host compiler's major version and so newer minor versions
      of the compilers listed below will be supported, but major versions falling outside the range
      will not be supported.

    NOTE: These constraints don't apply to Jetson, which uses something else.

    NOTE: NVIDIA can and will add support for newer compilers even during patch releases.
    E.g.: CUDA 12.2.1 maxxed out with support for Clang 15.0; 12.2.2 added support for Clang 16.0.

    NOTE: Because all platforms NVIDIA supports use GCC and Clang, we omit the architectures here.

    # Type

    ```
    nvccCompatibilities :: Attrs
    ```
  */
  nvccCompatibilities = {
    # Added support for GCC 12
    # https://docs.nvidia.com/cuda/archive/12.0.1/cuda-installation-guide-linux/index.html#system-requirements
    "12.0" = {
      clang = {
        maxMajorVersion = "14";
        minMajorVersion = "7";
      };
      gcc = {
        maxMajorVersion = "12";
        minMajorVersion = "6";
      };
    };

    # Added support for Clang 15
    # https://docs.nvidia.com/cuda/archive/12.1.1/cuda-toolkit-release-notes/index.html#cuda-compilers-new-features
    "12.1" = {
      clang = {
        maxMajorVersion = "15";
        minMajorVersion = "7";
      };
      gcc = {
        maxMajorVersion = "12";
        minMajorVersion = "6";
      };
    };

    # Added support for Clang 16
    # https://docs.nvidia.com/cuda/archive/12.2.2/cuda-installation-guide-linux/index.html#host-compiler-support-policy
    "12.2" = {
      clang = {
        maxMajorVersion = "16";
        minMajorVersion = "7";
      };
      gcc = {
        maxMajorVersion = "12";
        minMajorVersion = "6";
      };
    };

    # No changes from 12.2 to 12.3
    # https://docs.nvidia.com/cuda/archive/12.3.2/cuda-installation-guide-linux/index.html#host-compiler-support-policy
    "12.3" = {
      clang = {
        maxMajorVersion = "16";
        minMajorVersion = "7";
      };
      gcc = {
        maxMajorVersion = "12";
        minMajorVersion = "6";
      };
    };

    # Maximum Clang version is 17
    # Minimum GCC version is still 6, but all versions prior to GCC 7.3 are deprecated.
    # Maximum GCC version is 13.2
    # https://docs.nvidia.com/cuda/archive/12.4.1/cuda-installation-guide-linux/index.html#host-compiler-support-policy
    "12.4" = {
      clang = {
        maxMajorVersion = "17";
        minMajorVersion = "7";
      };
      gcc = {
        maxMajorVersion = "13";
        minMajorVersion = "6";
      };
    };

    # No changes from 12.4 to 12.5
    # https://docs.nvidia.com/cuda/archive/12.5.1/cuda-installation-guide-linux/index.html#host-compiler-support-policy
    "12.5" = {
      clang = {
        maxMajorVersion = "17";
        minMajorVersion = "7";
      };
      gcc = {
        maxMajorVersion = "13";
        minMajorVersion = "6";
      };
    };

    # Maximum Clang version is 18
    # https://docs.nvidia.com/cuda/archive/12.6.0/cuda-installation-guide-linux/index.html#host-compiler-support-policy
    "12.6" = {
      clang = {
        maxMajorVersion = "18";
        minMajorVersion = "7";
      };
      gcc = {
        maxMajorVersion = "13";
        minMajorVersion = "6";
      };
    };

    # Maximum Clang version is 19, maximum GCC version is 14
    # https://docs.nvidia.com/cuda/archive/12.6.0/cuda-installation-guide-linux/index.html#host-compiler-support-policy
    "12.8" = {
      clang = {
        maxMajorVersion = "19";
        minMajorVersion = "7";
      };
      gcc = {
        maxMajorVersion = "14";
        minMajorVersion = "6";
      };
    };
  };
}
