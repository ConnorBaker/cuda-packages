{ cudaLib, lib, ... }:
let
  inherit (cudaLib.types) attrs cudaCapability gpuInfo;
  inherit (lib.options) mkOption;
in
{
  options.data.gpus = mkOption {
    description = ''
      Attribute set of supported GPUs, mapping `cudaCapability` to information.

      Many thanks to Arnon Shimoni for maintaining a list of these architectures and capabilities.
      Without your work, this would have been much more difficult.
      https://arnon.dk/matching-sm-architectures-arch-and-gencode-for-various-nvidia-cards/
    '';
    type = attrs cudaCapability gpuInfo;
  };
  config.data.gpus = {
    "5.0" = {
      # Tesla/Quadro M series
      archName = "Maxwell";
      isJetson = false;
      minCudaMajorMinorVersion = "10.0";
      dontDefaultAfterCudaMajorMinorVersion = "11.0";
      maxCudaMajorMinorVersion = null;
    };
    "5.2" = {
      # Quadro M6000 , GeForce 900, GTX-970, GTX-980, GTX Titan X
      archName = "Maxwell";
      isJetson = false;
      minCudaMajorMinorVersion = "10.0";
      dontDefaultAfterCudaMajorMinorVersion = "11.0";
      maxCudaMajorMinorVersion = null;
    };
    "6.0" = {
      # Quadro GP100, Tesla P100, DGX-1 (Generic Pascal)
      archName = "Pascal";
      isJetson = false;
      minCudaMajorMinorVersion = "10.0";
      dontDefaultAfterCudaMajorMinorVersion = null;
      maxCudaMajorMinorVersion = null;
    };
    "6.1" = {
      # GTX 1080, GTX 1070, GTX 1060, GTX 1050, GTX 1030 (GP108), GT 1010 (GP108) Titan Xp, Tesla
      # P40, Tesla P4, Discrete GPU on the NVIDIA Drive PX2
      archName = "Pascal";
      isJetson = false;
      minCudaMajorMinorVersion = "10.0";
      dontDefaultAfterCudaMajorMinorVersion = null;
      maxCudaMajorMinorVersion = null;
    };
    "7.0" = {
      # DGX-1 with Volta, Tesla V100, GTX 1180 (GV104), Titan V, Quadro GV100
      archName = "Volta";
      isJetson = false;
      minCudaMajorMinorVersion = "10.0";
      dontDefaultAfterCudaMajorMinorVersion = null;
      maxCudaMajorMinorVersion = null;
    };
    "7.2" = {
      # Jetson AGX Xavier, Drive AGX Pegasus, Xavier NX
      archName = "Volta";
      isJetson = true;
      minCudaMajorMinorVersion = "10.0";
      dontDefaultAfterCudaMajorMinorVersion = null;
      # Note: without `cuda_compat`, maxCudaMajorMinorVersion is 11.8
      # https://docs.nvidia.com/cuda/cuda-for-tegra-appnote/index.html#deployment-considerations-for-cuda-upgrade-package
      maxCudaMajorMinorVersion = "12.2";
    };
    "7.5" = {
      # GTX/RTX Turing – GTX 1660 Ti, RTX 2060, RTX 2070, RTX 2080, Titan RTX, Quadro RTX 4000,
      # Quadro RTX 5000, Quadro RTX 6000, Quadro RTX 8000, Quadro T1000/T2000, Tesla T4
      archName = "Turing";
      isJetson = false;
      minCudaMajorMinorVersion = "10.0";
      dontDefaultAfterCudaMajorMinorVersion = null;
      maxCudaMajorMinorVersion = null;
    };
    "8.0" = {
      # NVIDIA A100 (the name “Tesla” has been dropped – GA100), NVIDIA DGX-A100
      archName = "Ampere";
      isJetson = false;
      minCudaMajorMinorVersion = "11.2";
      dontDefaultAfterCudaMajorMinorVersion = null;
      maxCudaMajorMinorVersion = null;
    };
    "8.6" = {
      # Tesla GA10x cards, RTX Ampere – RTX 3080, GA102 – RTX 3090, RTX A2000, A3000, RTX A4000,
      # A5000, A6000, NVIDIA A40, GA106 – RTX 3060, GA104 – RTX 3070, GA107 – RTX 3050, RTX A10, RTX
      # A16, RTX A40, A2 Tensor Core GPU
      archName = "Ampere";
      isJetson = false;
      minCudaMajorMinorVersion = "11.2";
      dontDefaultAfterCudaMajorMinorVersion = null;
      maxCudaMajorMinorVersion = null;
    };
    "8.7" = {
      # Jetson AGX Orin and Drive AGX Orin only
      archName = "Ampere";
      isJetson = true;
      minCudaMajorMinorVersion = "11.5";
      dontDefaultAfterCudaMajorMinorVersion = null;
      maxCudaMajorMinorVersion = null;
    };
    "8.9" = {
      # NVIDIA GeForce RTX 4090, RTX 4080, RTX 6000, Tesla L40
      archName = "Ada";
      isJetson = false;
      minCudaMajorMinorVersion = "11.8";
      dontDefaultAfterCudaMajorMinorVersion = null;
      maxCudaMajorMinorVersion = null;
    };
    "9.0" = {
      # NVIDIA H100 (GH100)
      archName = "Hopper";
      isJetson = false;
      minCudaMajorMinorVersion = "11.8";
      dontDefaultAfterCudaMajorMinorVersion = null;
      maxCudaMajorMinorVersion = null;
    };
    "9.0a" = {
      # NVIDIA H100 (GH100) (Thor)
      archName = "Hopper";
      isJetson = false;
      minCudaMajorMinorVersion = "12.0";
      dontDefaultAfterCudaMajorMinorVersion = null;
      maxCudaMajorMinorVersion = null;
    };
  };
}
