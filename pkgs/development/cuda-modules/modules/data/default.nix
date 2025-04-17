{
  config,
  cudaLib,
  lib,
  ...
}:
let
  inherit (cudaLib.types) attrs cudaCapability;
  inherit (cudaLib.utils) mkOptions;
  inherit (lib.attrsets) attrNames;
  inherit (lib.lists) groupBy sort;
  inherit (lib.strings) versionOlder;
  inherit (lib.types) nonEmptyListOf nonEmptyStr;
in
{
  imports = [
    ./cuda-capability-to-info.nix
    ./nvcc-compatibilities.nix
  ];

  options.data = mkOptions {
    cudaCapabilities = {
      description = ''
        All CUDA capabilities, sorting by version.
        Includes accelerated and Jetson capabilities.
      '';
      type = nonEmptyListOf cudaCapability;
    };

    cudaArchNameToCapabilities = {
      description = ''
        Mapping of CUDA micro-architecture name to capabilities belonging to that family.
      '';
      type = attrs nonEmptyStr (nonEmptyListOf cudaCapability);
    };
  };

  config.data = {
    cudaCapabilities = sort versionOlder (attrNames config.data.cudaCapabilityToInfo);

    cudaArchNameToCapabilities = groupBy (
      cudaCapability: config.data.cudaCapabilityToInfo.${cudaCapability}.archName
    ) config.data.cudaCapabilities;
  };
}
