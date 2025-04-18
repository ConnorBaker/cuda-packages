{
  config,
  cudaLib,
  cudaMajorMinorVersion,
  lib,
  pkgs,
  stdenv,
  stdenvAdapters,
}:
let
  inherit (builtins) toJSON;
  inherit (cudaLib.data) allSortedCudaCapabilities cudaCapabilityToInfo nvccCompatibilities;
  inherit (cudaLib.utils)
    cudaCapabilityIsDefault
    cudaCapabilityIsSupported
    evaluateAssertions
    getRedistSystem
    mkCudaPackagesVersionedName
    ;
  inherit (lib) addErrorContext;
  inherit (lib.customisation) extendDerivation;
  inherit (lib.lists)
    filter
    groupBy
    head
    intersectLists
    length
    subtractLists
    ;

  # NOTE: By virtue of processing a sorted list, our groups will be sorted.
  cudaCapabilitiesByKind = groupBy (
    cudaCapability:
    let
      cudaCapabilityInfo = cudaCapabilityToInfo.${cudaCapability};
    in
    # NOTE: Assumption here that there are no accelerated Jetson capabilities
    if cudaCapabilityInfo.isAccelerated then
      "acceleratedCudaCapabilities"
    else if cudaCapabilityInfo.isJetson then
      "jetsonCudaCapabilities"
    else
      "cudaCapabilities"
  ) allSortedCudaCapabilities;

  passthruExtra = {
    nvccHostCCMatchesStdenvCC = cudaStdenv.cc == stdenv.cc;

    # The Nix system of the host platform.
    hostNixSystem = stdenv.hostPlatform.system;

    # The Nix system of the host platform for the CUDA redistributable.
    hostRedistSystem = getRedistSystem passthruExtra.hasJetsonCudaCapability stdenv.hostPlatform.system;

    # Sets whether packages should be built with forward compatibility.
    # TODO(@connorbaker): If the requested CUDA capabilities are not supported by the current CUDA version,
    # should we throw an evaluation warning and build with forward compatibility?
    cudaForwardCompat = config.cudaForwardCompat or false;

    # CUDA capabilities which are supported by the current CUDA version.
    supportedCudaCapabilities = filter (
      cudaCapability:
      cudaCapabilityIsSupported cudaMajorMinorVersion cudaCapabilityToInfo.${cudaCapability}
    ) allSortedCudaCapabilities;

    # Find the default set of capabilities for this CUDA version using the list of supported capabilities.
    # Does not include Jetson or accelerated capabilities.
    defaultCudaCapabilities = filter (
      cudaCapability: cudaCapabilityIsDefault cudaMajorMinorVersion cudaCapabilityToInfo.${cudaCapability}
    ) passthruExtra.supportedCudaCapabilities;

    # The resolved requested or default CUDA capabilities.
    cudaCapabilities =
      if config.cudaCapabilities or [ ] != [ ] then
        config.cudaCapabilities
      else
        passthruExtra.defaultCudaCapabilities;

    # Requested accelerated CUDA capabilities.
    requestedAcceleratedCudaCapabilities =
      intersectLists (cudaCapabilitiesByKind.acceleratedCudaCapabilities or [ ])
        passthruExtra.cudaCapabilities;

    # Whether the requested CUDA capabilities include accelerated CUDA capabilities.
    hasAcceleratedCudaCapability = passthruExtra.requestedAcceleratedCudaCapabilities != [ ];

    # The requested Jetson CUDA capabilities.
    requestedJetsonCudaCapabilities = intersectLists (cudaCapabilitiesByKind.jetsonCudaCapabilities
      or [ ]
    ) passthruExtra.cudaCapabilities;

    # Whether the requested CUDA capabilities include Jetson CUDA capabilities.
    hasJetsonCudaCapability = passthruExtra.requestedJetsonCudaCapabilities != [ ];
  };

  assertions =
    let
      # Jetson devices cannot be targeted by the same binaries which target non-Jetson devices. While
      # NVIDIA provides both `linux-aarch64` and `linux-sbsa` packages, which both target `aarch64`,
      # they are built with different settings and cannot be mixed.
      jetsonMesssagePrefix = "Jetson CUDA capabilities (${toJSON passthruExtra.requestedJetsonCudaCapabilities})";

      # Accelerated devices are not built by default and cannot be built with other capabilities.
      acceleratedMessagePrefix = "Accelerated CUDA capabilities (${toJSON passthruExtra.requestedAcceleratedCudaCapabilities})";

      # Remove all known capabilities from the user's list to find unrecognized capabilities.
      unrecognizedCudaCapabilities = subtractLists allSortedCudaCapabilities passthruExtra.cudaCapabilities;

      # Remove all supported capabilities from the user's list to find unsupported capabilities.
      unsupportedCudaCapabilities = subtractLists passthruExtra.supportedCudaCapabilities passthruExtra.cudaCapabilities;
    in
    [
      {
        message = "Unrecognized CUDA capabilities: ${toJSON unrecognizedCudaCapabilities}";
        assertion = unrecognizedCudaCapabilities == [ ];
      }
      {
        message = "Unsupported CUDA capabilities: ${toJSON unsupportedCudaCapabilities}";
        assertion = unsupportedCudaCapabilities == [ ];
      }
      {
        message =
          "${jetsonMesssagePrefix} require hostPlatform (currently ${passthruExtra.hostNixSystem}) "
          + "to be aarch64";
        assertion = passthruExtra.hasJetsonCudaCapability -> passthruExtra.hostNixSystem == "aarch64-linux";
      }
      {
        message =
          let
            # Find the capabilities which are not Jetson capabilities.
            requestedNonJetsonCudaCapabilities = subtractLists (
              passthruExtra.requestedJetsonCudaCapabilities ++ passthruExtra.requestedAcceleratedCudaCapabilities
            ) passthruExtra.cudaCapabilities;
          in
          "${jetsonMesssagePrefix} cannot be specified with non-Jetson capabilities "
          + "(${toJSON requestedNonJetsonCudaCapabilities})";
        assertion =
          passthruExtra.hasJetsonCudaCapability
          -> passthruExtra.requestedJetsonCudaCapabilities == passthruExtra.cudaCapabilities;
      }
      {
        message = "${acceleratedMessagePrefix} do not support forward compatibility.";
        assertion = passthruExtra.hasAcceleratedCudaCapability -> !passthruExtra.cudaForwardCompat;
      }
      {
        message =
          let
            requestedAcceleratedCudaCapability = head passthruExtra.requestedAcceleratedCudaCapabilities;
            otherCudaCapabilities = filter (
              cudaCapability: cudaCapability != requestedAcceleratedCudaCapability
            ) passthruExtra.cudaCapabilities;
          in
          "${acceleratedMessagePrefix} cannot be specified with any other capability "
          + "(${toJSON otherCudaCapabilities}).";
        assertion =
          passthruExtra.hasAcceleratedCudaCapability -> length passthruExtra.cudaCapabilities == 1;
      }
    ];

  assertCondition = addErrorContext "while evaluating ${mkCudaPackagesVersionedName cudaMajorMinorVersion}.cudaStdenv" (
    evaluateAssertions assertions
  );

  # This is what nvcc uses as a backend,
  # and it has to be an officially supported one (e.g. gcc11 for cuda11).
  #
  # It, however, propagates current stdenv's libstdc++ to avoid "GLIBCXX_* not found errors"
  # when linked with other C++ libraries.
  # E.g. for cudaPackages_11_8 we use gcc11 with gcc12's libstdc++
  # Cf. https://github.com/NixOS/nixpkgs/pull/218265 for context
  cudaStdenv =
    stdenvAdapters.useLibsFrom stdenv
      pkgs."gcc${nvccCompatibilities.${cudaMajorMinorVersion}.gcc.maxMajorVersion}Stdenv";
in
# TODO: Consider testing whether we in fact use the newer libstdc++
extendDerivation assertCondition passthruExtra cudaStdenv
