{ cuda-lib, lib, ... }:
let
  inherit (cuda-lib.utils) mkOptions;
  inherit (lib.options) mkOption;
  inherit (lib.types) submodule;
in
{
  options.data.nvccCompatibilities = mkOption {
    description = ''
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
    '';
    type = cuda-lib.types.attrs cuda-lib.types.majorMinorVersion (
      cuda-lib.types.attrs cuda-lib.types.hostCompiler (submodule {
        options = mkOptions {
          maxMajorVersion = {
            description = "The maximum major version of a compiler supported by the NVCC available with this CUDA version.";
            type = cuda-lib.types.majorVersion;
          };
          minMajorVersion = {
            description = "The minimum major version of a compiler supported by the NVCC available with this CUDA version.";
            type = cuda-lib.types.majorVersion;
          };
        };
      })
    );
    default = {
      # Our baseline
      # https://docs.nvidia.com/cuda/archive/10.0/cuda-toolkit-release-notes/index.html#cuda-compiler-new-features
      "10.0" = {
        clang = {
          maxMajorVersion = "6";
          minMajorVersion = "6";
        };
        gcc = {
          maxMajorVersion = "7";
          minMajorVersion = "5";
        };
      };

      # Added support for Clang 7 and GCC 8
      # https://docs.nvidia.com/cuda/archive/10.1/cuda-toolkit-release-notes/index.html#cuda-compiler-new-features
      "10.1" = {
        clang = {
          maxMajorVersion = "7";
          minMajorVersion = "6";
        };
        gcc = {
          maxMajorVersion = "8";
          minMajorVersion = "5";
        };
      };

      # Added clang 8
      # https://docs.nvidia.com/cuda/archive/10.2/cuda-toolkit-release-notes/index.html#cuda-compiler-new-features
      "10.2" = {
        clang = {
          maxMajorVersion = "8";
          minMajorVersion = "6";
        };
        gcc = {
          maxMajorVersion = "8";
          minMajorVersion = "5";
        };
      };

      # Added support for Clang 9 and GCC 9
      # https://docs.nvidia.com/cuda/archive/11.0/cuda-toolkit-release-notes/index.html#cuda-compiler-new-features
      "11.0" = {
        clang = {
          maxMajorVersion = "9";
          minMajorVersion = "7";
        };
        gcc = {
          maxMajorVersion = "9";
          minMajorVersion = "6";
        };
      };

      # Added support for Clang 10 and GCC 10
      # https://docs.nvidia.com/cuda/archive/11.1.1/cuda-toolkit-release-notes/index.html#cuda-compiler-new-features
      "11.1" = {
        clang = {
          maxMajorVersion = "10";
          minMajorVersion = "7";
        };
        gcc = {
          maxMajorVersion = "10";
          minMajorVersion = "6";
        };
      };

      # Added support for Clang 11
      # https://docs.nvidia.com/cuda/archive/11.2.2/cuda-installation-guide-linux/index.html#system-requirements
      "11.2" = {
        clang = {
          maxMajorVersion = "10";
          minMajorVersion = "7";
        };
        gcc = {
          maxMajorVersion = "10";
          minMajorVersion = "6";
        };
      };

      # No changes from 11.2 to 11.3
      "11.3" = {
        clang = {
          maxMajorVersion = "10";
          minMajorVersion = "7";
        };
        gcc = {
          maxMajorVersion = "10";
          minMajorVersion = "6";
        };
      };

      # Added support for Clang 12 and GCC 11
      # https://docs.nvidia.com/cuda/archive/11.4.4/cuda-toolkit-release-notes/index.html#cuda-general-new-features
      "11.4" = {
        clang = {
          maxMajorVersion = "12";
          minMajorVersion = "7";
        };
        gcc = {
          # NOTE: There is a bug in the version of GLIBC that GCC 11 uses which causes it to fail to compile some CUDA
          # code. As such, we skip it for this release, and do the bump in 11.6 (skipping 11.5).
          # https://forums.developer.nvidia.com/t/cuda-11-5-samples-throw-multiple-error-attribute-malloc-does-not-take-arguments/192750/15
          # maxMajorVersion = "11";
          maxMajorVersion = "10";
          minMajorVersion = "6";
        };
      };

      # No changes from 11.4 to 11.5
      "11.5" = {
        clang = {
          maxMajorVersion = "12";
          minMajorVersion = "7";
        };
        gcc = {
          maxMajorVersion = "10";
          minMajorVersion = "6";
        };
      };

      # No changes from 11.5 to 11.6
      # However, as mentioned above, we add GCC 11 this release.
      "11.6" = {
        clang = {
          maxMajorVersion = "12";
          minMajorVersion = "7";
        };
        gcc = {
          maxMajorVersion = "11";
          minMajorVersion = "6";
        };
      };

      # Added support for Clang 13
      # https://docs.nvidia.com/cuda/archive/11.7.1/cuda-toolkit-release-notes/index.html#cuda-compiler-new-features
      "11.7" = {
        clang = {
          maxMajorVersion = "13";
          minMajorVersion = "7";
        };
        gcc = {
          maxMajorVersion = "11";
          minMajorVersion = "6";
        };
      };

      # Added support for Clang 14
      # https://docs.nvidia.com/cuda/archive/11.8.0/cuda-installation-guide-linux/index.html#system-requirements
      "11.8" = {
        clang = {
          maxMajorVersion = "14";
          minMajorVersion = "7";
        };
        gcc = {
          maxMajorVersion = "11";
          minMajorVersion = "6";
        };
      };

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
    };
  };
}
