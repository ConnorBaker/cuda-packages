top@{
  cudaLib,
  lib,
  ...
}:
let
  inherit (builtins) toJSON throw warn;
  inherit (cudaConfig.data) cudaCapabilityToInfo;
  inherit (cudaLib.types)
    attrs
    cudaPackagesConfig
    majorMinorPatchVersion
    ;
  inherit (cudaLib.utils)
    collectPackageConfigsForCudaVersion
    cudaCapabilityIsDefault
    cudaCapabilityIsSupported
    getRedistSystem
    mkOptionsModule
    ;
  inherit (lib.attrsets) genAttrs;
  inherit (lib.options) mkOption;
  inherit (lib.lists)
    filter
    foldl'
    intersectLists
    head
    length
    subtractLists
    ;
  inherit (lib.modules) mkMerge mkOptionDefault;
  inherit (lib.strings) optionalString versionOlder;
  inherit (lib.types) submodule;

  cudaConfig = top.config;

  mkFailedAssertionsString = foldl' (
    failedAssertionsString:
    { assertion, message, ... }:
    failedAssertionsString + optionalString (!assertion) ("\n- " + message)
  ) "";

  mkWarningsString = foldl' (warningsString: warning: warningsString + "\n- " + warning) "";

  mkPackageConfigsAssertWarn =
    cudaPackagesConfig:
    let
      inherit (cudaPackagesConfig) assertions cudaMajorMinorPatchVersion warnings;
      failedAssertionsString = mkFailedAssertionsString assertions;
      warningsString = mkWarningsString warnings;
      packageConfigs = mkMerge (
        collectPackageConfigsForCudaVersion cudaConfig cudaMajorMinorPatchVersion
      );
    in
    if failedAssertionsString != "" then
      throw "\nFailed assertions when constructing CUDA ${cudaMajorMinorPatchVersion} package set:${failedAssertionsString}"
    else if warningsString != "" then
      warn "\nWarnings when constructing CUDA ${cudaMajorMinorPatchVersion} package set:${warningsString}" packageConfigs
    else
      packageConfigs;

  mkCudaPackagesConfig =
    cudaPackagesConfig:
    let
      # The value for CUDA version is the attribute name since this attribute set is indexed by CUDA version.
      cudaMajorMinorPatchVersion = cudaPackagesConfig._module.args.name;

      # Remove all known capabilities from the user's list to find unrecognized capabilities.
      unrecognizedCudaCapabilities = subtractLists cudaConfig.data.allCudaCapabilities cudaPackagesConfig.cudaCapabilities;

      # Remove all supported capabilities from the user's list to find unsupported capabilities.
      unsupportedCudaCapabilities = subtractLists cudaPackagesConfig.supportedCudaCapabilities cudaPackagesConfig.cudaCapabilities;

      # Find the intersection of the user's capabilities and the Jetson capabilities.
      requestedJetsonCudaCapabilities = intersectLists cudaConfig.data.jetsonCudaCapabilities cudaPackagesConfig.cudaCapabilities;

      # Find the intersection of the user's capabilities and the accelerated capabilities.
      requestedAcceleratedCudaCapabilities = intersectLists cudaConfig.data.acceleratedCudaCapabilities cudaPackagesConfig.cudaCapabilities;

      # Find the capabilities which are not Jetson capabilities.
      requestedNonJetsonCudaCapabilities = subtractLists (
        requestedJetsonCudaCapabilities ++ requestedAcceleratedCudaCapabilities
      ) cudaPackagesConfig.cudaCapabilities;
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
            message = "${jetsonMesssagePrefix} require hostPlatform (currently ${cudaConfig.hostNixSystem}) to be aarch64";
          }
          {
            assertion =
              cudaPackagesConfig.hasJetsonCudaCapability
              -> requestedJetsonCudaCapabilities == cudaPackagesConfig.cudaCapabilities;
            message = "${jetsonMesssagePrefix} cannot be specified with non-Jetson capabilities (${toJSON requestedNonJetsonCudaCapabilities})";
          }
          {
            assertion =
              cudaPackagesConfig.hasAcceleratedCudaCapability -> !cudaPackagesConfig.cudaForwardCompat;
            message = "${acceleratedMessagePrefix} do not support forward compatibility.";
          }
          {
            assertion =
              cudaPackagesConfig.hasAcceleratedCudaCapability -> length cudaPackagesConfig.cudaCapabilities == 1;
            message =
              let
                requestedAcceleratedCudaCapability = head requestedAcceleratedCudaCapabilities;
                otherCudaCapabilities = filter (
                  cudaCapability: cudaCapability != requestedAcceleratedCudaCapability
                ) cudaPackagesConfig.cudaCapabilities;
              in
              "${acceleratedMessagePrefix} cannot be specified with any other capability (${toJSON otherCudaCapabilities}).";
          }
          {
            assertion = cudaPackagesConfig.cudaMajorMinorPatchVersion == cudaPackagesConfig.redists.cuda;
            message = "CUDA version (${cudaPackagesConfig.cudaMajorMinorPatchVersion}) does not match redist version (${cudaPackagesConfig.redists.cuda})";
          }
        ];

      warnings = [ ];

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
          cudaCapabilityToInfo.${cudaCapability}
      ) cudaConfig.data.allCudaCapabilities;

      # Find the default set of capabilities for this CUDA version using the list of supported capabilities.
      # Does not include Jetson or accelerated capabilities.
      defaultCudaCapabilities = filter (
        cudaCapability:
        cudaCapabilityIsDefault cudaPackagesConfig.cudaMajorMinorPatchVersion
          cudaCapabilityToInfo.${cudaCapability}
      ) cudaPackagesConfig.supportedCudaCapabilities;

      cudaForwardCompat = mkOptionDefault cudaConfig.cudaForwardCompat;
      hasJetsonCudaCapability = requestedJetsonCudaCapabilities != [ ];
      hasAcceleratedCudaCapability = requestedAcceleratedCudaCapabilities != [ ];
      hostRedistSystem = getRedistSystem cudaPackagesConfig.hasJetsonCudaCapability cudaConfig.hostNixSystem;
      redists.cuda = cudaPackagesConfig.cudaMajorMinorPatchVersion;
      packageConfigs = mkPackageConfigsAssertWarn cudaPackagesConfig;
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

  # Allow users extending CUDA package sets to specify the redist version to use.
  options.cudaPackages = mkOption {
    description = ''
      Versioned configuration options for each version of CUDA package set produced.
    '';
    type = attrs majorMinorPatchVersion cudaPackagesConfig;
    default = { };
  };

  config.cudaPackages = genAttrs cudaConfig.data.cudaMajorMinorPatchVersions (
    cudaMajorMinorPatchVersion:
    let
      cudaPackagesConfig = cudaConfig.cudaPackages.${cudaMajorMinorPatchVersion};
    in
    {
      packagesDirectories = [ ../packages/common ];
      redists = {
        cublasmp = "0.3.1";
        cudnn = "9.7.1";
        cudss = "0.4.0";
        cuquantum = "24.11.0";
        cusolvermp = "0.6.0";
        cusparselt =
          if versionOlder cudaPackagesConfig.cudaMajorMinorPatchVersion "12.8.0" then "0.6.3" else "0.7.0";
        cutensor = "2.1.0";
        nppplus = "0.9.0";
        nvjpeg2000 = "0.8.1";
        nvpl = "25.1";
        nvtiff = "0.4.0";
        tensorrt = if cudaPackagesConfig.hasJetsonCudaCapability then "10.7.0" else "10.8.0";
      };
    }
  );
}
