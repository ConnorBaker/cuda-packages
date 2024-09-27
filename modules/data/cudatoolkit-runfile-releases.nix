{ cuda-lib, lib, ... }:
let
  inherit (cuda-lib.utils) mkOptions;
  inherit (lib.options) mkOption;
  inherit (lib.types) nonEmptyStr submodule;
in
{
  options.data.cudatoolkitRunfileReleases = mkOption {
    description = "List of CUDA runfile releases";
    type = cuda-lib.types.attrs cuda-lib.types.versionMajorMinor (submodule {
      options = mkOptions {
        hash.type = cuda-lib.types.sriHash;
        url.type = nonEmptyStr;
        version.type = cuda-lib.types.majorMinorPatchVersion;
      };
    });
    default = {
      "10.0" = {
        version = "10.0.130";
        url = "https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_410.48_linux";
        hash = "sha256-kjUfDkNGaU0Py06hU5hWyeuCBgwlZURjv9hXTsNe45o=";
      };

      "10.1" = {
        version = "10.1.243";
        url = "https://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_418.87.00_linux.run";
        hash = "sha256-58ItwhJ46xuC80pgrXZAtBrTlD2Sm+vaMAi3JTaFXTE=";
      };

      "10.2" = {
        version = "10.2.89";
        url = "http://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda_10.2.89_440.33.01_linux.run";
        hash = "sha256-Vg0H/c9KRnF/IkKUjNT5LF+bb8fq4Q3ZlmFNqRPVyhE=";
      };

      "11.0" = {
        version = "11.0.3";
        url = "https://developer.download.nvidia.com/compute/cuda/11.0.3/local_installers/cuda_11.0.3_450.51.06_linux.run";
        hash = "sha256-sHnE5Ait+Iw/H/uEGKl9xCJ8N5NWdrS/TKC+7GwyjMA=";
      };

      "11.1" = {
        version = "11.1.1";
        url = "https://developer.download.nvidia.com/compute/cuda/11.1.1/local_installers/cuda_11.1.1_455.32.00_linux.run";
        hash = "sha256-Pq5nJwhgJJJeu87z6aRa03nYSQdo/QD5wti2/ZzY3Y8=";
      };

      "11.2" = {
        version = "11.2.1";
        url = "https://developer.download.nvidia.com/compute/cuda/11.2.1/local_installers/cuda_11.2.1_460.32.03_linux.run";
        hash = "sha256-HamMuJfMX1inRFpKZspPaSaGdwbLOvWKZpzc2Nw9F8g=";
      };

      "11.3" = {
        version = "11.3.1";
        url = "https://developer.download.nvidia.com/compute/cuda/11.3.1/local_installers/cuda_11.3.1_465.19.01_linux.run";
        hash = "sha256-rZPqmO/O01hVxY06D8MmN3xgkXyz6MAX0+bYiBm/KTQ=";
      };

      "11.4" = {
        version = "11.4.2";
        url = "https://developer.download.nvidia.com/compute/cuda/11.4.2/local_installers/cuda_11.4.2_470.57.02_linux.run";
        hash = "sha256-u9h8oOkT+DdFSnljZ0c1E83e9VUILk2G7Zo4ZZzIHwo=";
      };

      "11.5" = {
        version = "11.5.0";
        url = "https://developer.download.nvidia.com/compute/cuda/11.5.0/local_installers/cuda_11.5.0_495.29.05_linux.run";
        hash = "sha256-rgoWk9lJfPPYHmlIlD43lGNpANtxyY1Y7v2sr38aHkw=";
      };

      "11.6" = {
        version = "11.6.1";
        url = "https://developer.download.nvidia.com/compute/cuda/11.6.1/local_installers/cuda_11.6.1_510.47.03_linux.run";
        hash = "sha256-qyGa/OALdCABEyaYZvv/derQN7z8I1UagzjCaEyYTX4=";
      };

      "11.7" = {
        version = "11.7.0";
        url = "https://developer.download.nvidia.com/compute/cuda/11.7.0/local_installers/cuda_11.7.0_515.43.04_linux.run";
        hash = "sha256-CH/fy7ofeVQ7H3jkOo39rF9tskLQQt3oIOFtwYWJLyY=";
      };

      "11.8" = {
        version = "11.8.0";
        url = "https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run";
        hash = "sha256-kiPErzrr5Ke77Zq9mxY7A6GzS4VfvCtKDRtwasCaWhY=";
      };

      "12.0" = {
        version = "12.0.1";
        url = "https://developer.download.nvidia.com/compute/cuda/12.0.1/local_installers/cuda_12.0.1_525.85.12_linux.run";
        hash = "sha256-GyBaBicvFGP0dydv2rkD8/ZmkXwGjlIHOAAeacehh1s=";
      };

      "12.1" = {
        version = "12.1.1";
        url = "https://developer.download.nvidia.com/compute/cuda/12.1.1/local_installers/cuda_12.1.1_530.30.02_linux.run";
        hash = "sha256-10Ai1B2AEFMZ36Ib7qObd6W5kZU5wEh6BcqvJEbWpw4=";
      };

      "12.2" = {
        version = "12.2.2";
        url = "https://developer.download.nvidia.com/compute/cuda/12.2.2/local_installers/cuda_12.2.2_535.104.05_linux.run";
        hash = "sha256-Kzmq4+dhjZ9Zo8j6HxvGHynAsODfdfsFB2uts1KVLvI=";
      };

      "12.3" = {
        version = "12.3.2";
        url = "https://developer.download.nvidia.com/compute/cuda/12.3.2/local_installers/cuda_12.3.2_545.23.08_linux.run";
        hash = "sha256-JLKvyfdw2M9D1vp63C6/1HxAhNsBvdoc484KTUk7pls=";
      };

      "12.4" = {
        version = "12.4.1";
        url = "https://developer.download.nvidia.com/compute/cuda/12.4.1/local_installers/cuda_12.4.1_550.54.15_linux.run";
        hash = "sha256-Nn0imbOkWIq0h6bScnbKXZ6tbjlJBPGLzLnhJDO5xPs=";
      };

      "12.5" = {
        version = "12.5.1";
        url = "https://developer.download.nvidia.com/compute/cuda/12.5.1/local_installers/cuda_12.5.1_555.42.06_linux.run";
        hash = "sha256-teCneeCJyGYQBRFBxM9Ji+70MYWOxjOYEHORcn7L2wQ=";
      };

      "12.6" = {
        version = "12.6.1";
        url = "https://developer.download.nvidia.com/compute/cuda/12.6.1/local_installers/cuda_12.6.1_560.35.03_linux.run";
        hash = "sha256-c6zOckNRliXyWVCfXc/23I+9I9ylO4Uqqc44IAnpLp0=";
      };
    };
  };
}
