{
  config,
  cudaLib,
  lib,
  ...
}:
let
  inherit (cudaLib.types) attrs cudaCapability majorMinorPatchVersion;
  inherit (cudaLib.utils) mkOptions;
  inherit (lib.attrsets) attrNames;
  inherit (lib.lists) groupBy sort;
  inherit (lib.strings) versionOlder;
  inherit (lib.types) listOf nonEmptyListOf nonEmptyStr;

  # NOTE: By virtue of processing a sorted list, our groups will be sorted.
  groupedCudaCapabilities = groupBy (
    cudaCapability:
    let
      cudaCapabilityInfo = config.data.cudaCapabilityToInfo.${cudaCapability};
    in
    # NOTE: Assumption here that there are no accelerated Jetson capabilities
    if cudaCapabilityInfo.isAccelerated then
      "acceleratedCudaCapabilities"
    else if cudaCapabilityInfo.isJetson then
      "jetsonCudaCapabilities"
    else
      "cudaCapabilities"
  ) config.data.allCudaCapabilities;
in
{
  imports = [
    ./cuda-capability-to-info.nix
    ./nvcc-compatibilities.nix
  ];
  options.data = mkOptions {
    cudaMajorMinorPatchVersions = {
      description = ''
        List of CUDA major.minor.patch versions available across runfile installers and redist packages
      '';
      type = nonEmptyListOf majorMinorPatchVersion;
    };
    cudaArchNameToCapabilities = {
      description = ''
        Mapping of CUDA micro-architecture name to capabilities belonging to that family.
      '';
      type = attrs nonEmptyStr (nonEmptyListOf cudaCapability);
    };
    allCudaCapabilities = {
      description = ''
        List of all CUDA capabilities, include accelerated and Jetson capabilities.
        NOTE: These capabilities are sorted in ascending order.
      '';
      type = listOf cudaCapability;
    };
    cudaCapabilities = {
      description = ''
        List of non-accelerated, non-Jetson CUDA capabilities.
        NOTE: These capabilities are sorted in ascending order.
      '';
      type = listOf cudaCapability;
    };
    jetsonCudaCapabilities = {
      description = ''
        List of Jetson CUDA capabilities.
        NOTE: These capabilities are sorted in ascending order.
      '';
      type = listOf cudaCapability;
    };
    acceleratedCudaCapabilities = {
      description = ''
        List of accelerated CUDA capabilities.
        NOTE: These capabilities are sorted in ascending order.
      '';
      type = listOf cudaCapability;
    };
  };
  config.data = {
    acceleratedCudaCapabilities = groupedCudaCapabilities.acceleratedCudaCapabilities or [ ];
    allCudaCapabilities = sort versionOlder (attrNames config.data.cudaCapabilityToInfo);
    cudaArchNameToCapabilities = groupBy (
      cudaCapability: config.data.cudaCapabilityToInfo.${cudaCapability}.archName
    ) config.data.allCudaCapabilities;
    cudaCapabilities = groupedCudaCapabilities.cudaCapabilities or [ ];
    cudaMajorMinorPatchVersions = sort versionOlder (attrNames config.redists.cuda.versionedManifests);
    jetsonCudaCapabilities = groupedCudaCapabilities.jetsonCudaCapabilities or [ ];
  };
}
