{ cudaLib, lib, ... }:
let
  inherit (cudaLib.types) attrs cudaCapability cudaCapabilityInfo;
  inherit (lib.options) mkOption;
in
{
  options.data.cudaCapabilityToInfo = mkOption {
    description = ''
      Attribute set of supported CUDA capability mapped to information about that capability.

      NOTE: Building with architecture-accelerated features (capabilities with an `a` suffix) is neither forward nor
      backwards compatible with the base architecture. For example, device code targeting `10.0a` will not work on a
      a device presenting as `10.0`, and vice versa.

      Many thanks to Arnon Shimoni for maintaining a list of these architectures and capabilities.
      Without your work, this would have been much more difficult.
      https://arnon.dk/matching-sm-architectures-arch-and-gencode-for-various-nvidia-cards/
    '';
    type = attrs cudaCapability cudaCapabilityInfo;
  };
  config.data.cudaCapabilityToInfo = {
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
      isJetson = true;
      minCudaMajorMinorVersion = "10.0";
      # Note: without `cuda_compat`, maxCudaMajorMinorVersion is 11.8
      # https://docs.nvidia.com/cuda/cuda-for-tegra-appnote/index.html#deployment-considerations-for-cuda-upgrade-package
      maxCudaMajorMinorVersion = "12.2";
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
      isJetson = true;
      minCudaMajorMinorVersion = "11.5";
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
      isAccelerated = true;
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
      isAccelerated = true;
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
      isAccelerated = true;
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
      isAccelerated = true;
      minCudaMajorMinorVersion = "12.8";
    };
  };
}
