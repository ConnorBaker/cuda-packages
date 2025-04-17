{
  config,
  cudaCapabilities,
  cudaForwardCompat,
  cudaLib,
  defaultCudaMajorMinorPatchVersion,
  hostNixSystem,
  lib,
  ...
}:
let
  inherit (builtins) toJSON;
  inherit (cudaLib.types) cudaCapability majorMinorPatchVersion;
  inherit (cudaLib.utils)
    cudaCapabilityIsDefault
    cudaCapabilityIsSupported
    getRedistSystem
    mkOptions
    ;
  inherit (lib.lists)
    filter
    groupBy
    head
    intersectLists
    length
    subtractLists
    ;
  inherit (lib.types)
    bool
    listOf
    nonEmptyStr
    str
    unspecified
    ;

  # NOTE: By virtue of processing a sorted list, our groups will be sorted.
  cudaCapabilitiesByKind = groupBy (
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
  ) config.data.cudaCapabilities;

  acceleratedCudaCapabilities = cudaCapabilitiesByKind.acceleratedCudaCapabilities or [ ];
  requestedAcceleratedCudaCapabilities = intersectLists acceleratedCudaCapabilities config.cudaCapabilities;

  jetsonCudaCapabilities = cudaCapabilitiesByKind.jetsonCudaCapabilities or [ ];
  requestedJetsonCudaCapabilities = intersectLists jetsonCudaCapabilities config.cudaCapabilities;

  # CUDA capabilities which are supported by the current CUDA version.
  supportedCudaCapabilities = filter (
    cudaCapability:
    cudaCapabilityIsSupported config.defaultCudaMajorMinorPatchVersion
      config.data.cudaCapabilityToInfo.${cudaCapability}
  ) config.data.cudaCapabilities;

  # Find the default set of capabilities for this CUDA version using the list of supported capabilities.
  # Does not include Jetson or accelerated capabilities.
  defaultCudaCapabilities = filter (
    cudaCapability:
    cudaCapabilityIsDefault config.defaultCudaMajorMinorPatchVersion
      config.data.cudaCapabilityToInfo.${cudaCapability}
  ) supportedCudaCapabilities;
in
{
  imports = [ ./data ];

  options = mkOptions {
    # NOTE: assertions vendored from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/assertions.nix
    assertions = {
      type = listOf unspecified;
      internal = true;
      default = [ ];
      example = [
        {
          assertion = false;
          message = "you can't enable this for that reason";
        }
      ];
      description = ''
        This option allows the cudaPackages module to express conditions that must hold for the evaluation of the
        package set to succeed, along with associated error messages for the user.
      '';
    };

    # NOTE: warnings vendored from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/assertions.nix
    warnings = {
      internal = true;
      default = [ ];
      type = listOf str;
      example = [ "This package set is marked for removal" ];
      description = ''
        This option allows the cudaPackages module to show warnings to users during the evaluation of the package set
        configuration.
      '';
    };

    defaultCudaMajorMinorPatchVersion = {
      description = ''
        The default CUDA version to use when no version is specified.
        This is used to determine the default set of CUDA capabilities.
      '';
      type = majorMinorPatchVersion;
      default = defaultCudaMajorMinorPatchVersion;
    };

    cudaCapabilities = {
      description = ''
        Sets the default CUDA capabilities to target across all CUDA package sets.
        If empty, the default set of capabilities is determined by the default CUDA package set.
      '';
      type = listOf cudaCapability;
      default = if cudaCapabilities != [ ] then cudaCapabilities else defaultCudaCapabilities;
    };

    hasAcceleratedCudaCapability = {
      description = ''
        Whether the requested CUDA capabilities include accelerated CUDA capabilities.
      '';
      type = bool;
      default = requestedAcceleratedCudaCapabilities != [ ];
    };

    hasJetsonCudaCapability = {
      description = ''
        Whether the requested CUDA capabilities include Jetson CUDA capabilities.
      '';
      type = bool;
      default = requestedJetsonCudaCapabilities != [ ];
    };

    cudaForwardCompat = {
      description = ''
        Sets whether packages should be built with forward compatibility.
      '';
      type = bool;
      default = cudaForwardCompat;
    };

    hostNixSystem = {
      description = ''
        The Nix system of the host platform.
      '';
      type = nonEmptyStr;
      default = hostNixSystem;
    };

    hostRedistSystem = {
      description = ''
        The Nix system of the host platform for the CUDA redistributable.
      '';
      type = nonEmptyStr;
      default = getRedistSystem config.hasJetsonCudaCapability config.hostNixSystem;
    };
  };

  config = {
    assertions =
      let
        # Jetson devices cannot be targeted by the same binaries which target non-Jetson devices. While
        # NVIDIA provides both `linux-aarch64` and `linux-sbsa` packages, which both target `aarch64`,
        # they are built with different settings and cannot be mixed.
        jetsonMesssagePrefix = "Jetson CUDA capabilities (${toJSON requestedJetsonCudaCapabilities})";

        # Accelerated devices are not built by default and cannot be built with other capabilities.
        acceleratedMessagePrefix = "Accelerated CUDA capabilities (${toJSON requestedAcceleratedCudaCapabilities})";

        # Remove all known capabilities from the user's list to find unrecognized capabilities.
        unrecognizedCudaCapabilities = subtractLists config.data.cudaCapabilities config.cudaCapabilities;

        # Remove all supported capabilities from the user's list to find unsupported capabilities.
        unsupportedCudaCapabilities = subtractLists supportedCudaCapabilities config.cudaCapabilities;
      in
      [
        {
          assertion = unrecognizedCudaCapabilities == [ ];
          message = "Unrecognized CUDA capabilities: ${toJSON unrecognizedCudaCapabilities}";
        }
        {
          assertion = unsupportedCudaCapabilities == [ ];
          message = "Unsupported CUDA capabilities: ${toJSON unsupportedCudaCapabilities}";
        }
        {
          assertion = config.hasJetsonCudaCapability -> config.hostNixSystem == "aarch64-linux";
          message =
            "${jetsonMesssagePrefix} require hostPlatform (currently ${config.hostNixSystem}) "
            + "to be aarch64";
        }
        {
          assertion =
            config.hasJetsonCudaCapability -> requestedJetsonCudaCapabilities == config.cudaCapabilities;
          message =
            let
              # Find the capabilities which are not Jetson capabilities.
              requestedNonJetsonCudaCapabilities = subtractLists (
                requestedJetsonCudaCapabilities ++ requestedAcceleratedCudaCapabilities
              ) config.cudaCapabilities;
            in
            "${jetsonMesssagePrefix} cannot be specified with non-Jetson capabilities "
            + "(${toJSON requestedNonJetsonCudaCapabilities})";
        }
        {
          assertion = config.hasAcceleratedCudaCapability -> !config.cudaForwardCompat;
          message = "${acceleratedMessagePrefix} do not support forward compatibility.";
        }
        {
          assertion = config.hasAcceleratedCudaCapability -> length config.cudaCapabilities == 1;
          message =
            let
              requestedAcceleratedCudaCapability = head requestedAcceleratedCudaCapabilities;
              otherCudaCapabilities = filter (
                cudaCapability: cudaCapability != requestedAcceleratedCudaCapability
              ) config.cudaCapabilities;
            in
            "${acceleratedMessagePrefix} cannot be specified with any other capability "
            + "(${toJSON otherCudaCapabilities}).";
        }
      ];
  };
}
