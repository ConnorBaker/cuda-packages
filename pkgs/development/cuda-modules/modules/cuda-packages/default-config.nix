top@{
  cudaLib,
  lib,
  ...
}:
let
  inherit (builtins) toJSON throw warn;
  inherit (cudaConfig) data fixups manifests;
  inherit (cudaLib.types) attrs majorMinorPatchVersion;
  inherit (cudaLib.utils)
    cudaCapabilityIsDefault
    cudaCapabilityIsSupported
    getRedistSystem
    mkOptionsModule
    ;
  inherit (lib.attrsets) attrNames hasAttr;
  inherit (lib.lists)
    concatMap
    filter
    foldl'
    intersectLists
    head
    length
    subtractLists
    ;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault;
  inherit (lib.strings) optionalString;
  inherit (lib.types) submodule;

  cudaConfig = top.config;

  mkFailedAssertionsString = foldl' (
    failedAssertionsString:
    { assertion, message, ... }:
    failedAssertionsString + optionalString (!assertion) ("\n- " + message)
  ) "";

  mkWarningsString = foldl' (warningsString: warning: warningsString + "\n- " + warning) "";

  mkRedistBuilderArgsAssertWarn =
    cudaPackagesConfig:
    let
      inherit (cudaPackagesConfig) assertions cudaMajorMinorPatchVersion warnings;
      failedAssertionsString = mkFailedAssertionsString assertions;
      warningsString = mkWarningsString warnings;
      redistBuilderArgs = mkMerge (
        concatMap (
          redistName:
          let
            redistVersion = cudaPackagesConfig.redists.${redistName};
            manifest = manifests.${redistName}.${redistVersion};
          in
          # One benefit of using mkMerge is that, becuase all entries have the same priority, we should get errors
          # if there are collisions between package names across redists.
          map (
            packageName:
            # Only add the configuration for the package if it is in the manifest.
            (mkIf (hasAttr packageName manifest) {
              ${packageName} = {
                inherit packageName redistName;
                fixupFn = fixups.${redistName}.${packageName};
              };
            })
          ) (attrNames fixups.${redistName})
        ) (attrNames cudaPackagesConfig.redists)
      );
    in
    if failedAssertionsString != "" then
      throw "\nFailed assertions when constructing CUDA ${cudaMajorMinorPatchVersion} package set:${failedAssertionsString}"
    else if warningsString != "" then
      warn "\nWarnings when constructing CUDA ${cudaMajorMinorPatchVersion} package set:${warningsString}" redistBuilderArgs
    else
      redistBuilderArgs;

  mkCudaPackagesConfig =
    cudaPackagesConfig:
    let
      inherit (cudaPackagesConfig) cudaCapabilities;

      # The value for CUDA version is the attribute name since this attribute set is indexed by CUDA version.
      cudaMajorMinorPatchVersion = cudaPackagesConfig._module.args.name;

      # Remove all known capabilities from the user's list to find unrecognized capabilities.
      unrecognizedCudaCapabilities = subtractLists data.allCudaCapabilities cudaCapabilities;

      # Remove all supported capabilities from the user's list to find unsupported capabilities.
      unsupportedCudaCapabilities = subtractLists cudaPackagesConfig.supportedCudaCapabilities cudaCapabilities;

      # Find the intersection of the user's capabilities and the Jetson capabilities.
      requestedJetsonCudaCapabilities = intersectLists data.jetsonCudaCapabilities cudaCapabilities;

      # Find the intersection of the user's capabilities and the accelerated capabilities.
      requestedAcceleratedCudaCapabilities = intersectLists data.acceleratedCudaCapabilities cudaCapabilities;

      # Find the capabilities which are not Jetson capabilities.
      requestedNonJetsonCudaCapabilities = subtractLists (
        requestedJetsonCudaCapabilities ++ requestedAcceleratedCudaCapabilities
      ) cudaCapabilities;
    in
    # For both cudaCapabilities and cudaForwardCompat, use a very low priority so the user's value is used
    # instead of merging.
    {
      inherit cudaMajorMinorPatchVersion;

      assertions =
        let
          # Jetson devices cannot be targeted by the same binaries which target non-Jetson devices. While
          # NVIDIA provides both `linux-aarch64` and `linux-sbsa` packages, which both target `aarch64`,
          # they are built with different settings and cannot be mixed.
          jetsonMesssagePrefix = "Jetson CUDA capabilities (${toJSON requestedJetsonCudaCapabilities})";
          # Accelerated devices are not built by default and cannot be built with other capabilities.
          acceleratedMessagePrefix = "Accelerated CUDA capabilities (${toJSON requestedAcceleratedCudaCapabilities})";
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
            assertion =
              cudaPackagesConfig.hasJetsonCudaCapability -> cudaConfig.hostNixSystem == "aarch64-linux";
            message =
              "${jetsonMesssagePrefix} require hostPlatform (currently ${cudaConfig.hostNixSystem}) "
              + "to be aarch64";
          }
          {
            assertion =
              cudaPackagesConfig.hasJetsonCudaCapability -> requestedJetsonCudaCapabilities == cudaCapabilities;
            message =
              "${jetsonMesssagePrefix} cannot be specified with non-Jetson capabilities "
              + "(${toJSON requestedNonJetsonCudaCapabilities})";
          }
          {
            assertion =
              cudaPackagesConfig.hasAcceleratedCudaCapability -> !cudaPackagesConfig.cudaForwardCompat;
            message = "${acceleratedMessagePrefix} do not support forward compatibility.";
          }
          {
            assertion = cudaPackagesConfig.hasAcceleratedCudaCapability -> length cudaCapabilities == 1;
            message =
              let
                requestedAcceleratedCudaCapability = head requestedAcceleratedCudaCapabilities;
                otherCudaCapabilities = filter (
                  cudaCapability: cudaCapability != requestedAcceleratedCudaCapability
                ) cudaCapabilities;
              in
              "${acceleratedMessagePrefix} cannot be specified with any other capability "
              + "(${toJSON otherCudaCapabilities}).";
          }
          {
            assertion = cudaPackagesConfig.cudaMajorMinorPatchVersion == cudaPackagesConfig.redists.cuda;
            message =
              "CUDA version (${cudaPackagesConfig.cudaMajorMinorPatchVersion}) does not match redist version "
              + "(${cudaPackagesConfig.redists.cuda})";
          }
        ];

      warnings = [ ];

      # Default to the global CUDA capabilities if the user specified them;
      # otherwise, use the default set of capabilities for this CUDA version.
      cudaCapabilities = mkOptionDefault (
        if cudaConfig.cudaCapabilities != [ ] then
          cudaConfig.cudaCapabilities
        else
          cudaPackagesConfig.defaultCudaCapabilities
      );

      # CUDA capabilities which are supported by the current CUDA version.
      supportedCudaCapabilities = filter (
        cudaCapability:
        cudaCapabilityIsSupported cudaPackagesConfig.cudaMajorMinorPatchVersion
          data.cudaCapabilityToInfo.${cudaCapability}
      ) data.allCudaCapabilities;

      # Find the default set of capabilities for this CUDA version using the list of supported capabilities.
      # Does not include Jetson or accelerated capabilities.
      defaultCudaCapabilities = filter (
        cudaCapability:
        cudaCapabilityIsDefault cudaPackagesConfig.cudaMajorMinorPatchVersion
          data.cudaCapabilityToInfo.${cudaCapability}
      ) cudaPackagesConfig.supportedCudaCapabilities;

      cudaForwardCompat = mkOptionDefault cudaConfig.cudaForwardCompat;

      cudaForceRpath = mkOptionDefault cudaConfig.cudaForceRpath;

      hasJetsonCudaCapability = requestedJetsonCudaCapabilities != [ ];

      hasAcceleratedCudaCapability = requestedAcceleratedCudaCapabilities != [ ];

      hostRedistSystem = getRedistSystem cudaPackagesConfig.hasJetsonCudaCapability cudaConfig.hostNixSystem;

      redists.cuda = cudaPackagesConfig.cudaMajorMinorPatchVersion;

      redistBuilderArgs = mkRedistBuilderArgsAssertWarn cudaPackagesConfig;
    };
in
{
  # Use submodule merging to add a config block which is populated using the module fixpoint.
  # We do this here rather than below because these settings are sensible for all versions.
  imports = [
    (mkOptionsModule {
      cudaPackages.type = attrs majorMinorPatchVersion (
        submodule (inner: {
          config = mkCudaPackagesConfig inner.config;
        })
      );
    })
  ];
}
