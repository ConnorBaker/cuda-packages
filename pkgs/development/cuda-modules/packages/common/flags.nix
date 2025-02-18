{
  cudaConfig,
  cudaPackagesConfig,
  cudaLib,
  lib,
}:
lib.attrsets.dontRecurseIntoAttrs (
  cudaLib.utils.formatCapabilities {
    inherit (cudaConfig.data) cudaCapabilityToInfo;
    inherit (cudaPackagesConfig)
      cudaCapabilities
      cudaForwardCompat
      ;
  }
)
