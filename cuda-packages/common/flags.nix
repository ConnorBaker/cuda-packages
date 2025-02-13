{
  config,
  cudaConfig,
  cudaCapabilities ? (config.cudaCapabilities or [ ]),
  cudaForwardCompat ? (config.cudaForwardCompat or true),
  cudaLib,
  cudaMajorMinorVersion,
  lib,
  stdenv,
}:
let
  inherit (builtins) toJSON;
  inherit (cudaConfig.data) gpus;
  inherit (cudaLib.utils)
    dropDots
    gpuIsDefault
    gpuIsSupported
    mkCmakeCudaArchitecturesString
    mkGencodeFlag
    mkRealArchitecture
    mkVirtualArchitecture
    ;
  inherit (lib.attrsets)
    attrNames
    attrValues
    dontRecurseIntoAttrs
    filterAttrs
    mapAttrs
    ;
  inherit (lib.lists)
    elem
    filter
    groupBy'
    intersectLists
    last
    length
    map
    optionals
    unique
    ;
  inherit (lib.trivial) pipe throwIf;
  inherit (lib.strings) concatStringsSep;
  inherit (stdenv) hostPlatform;

  # Flags are determined based on your CUDA toolkit by default.  You may benefit
  # from improved performance, reduced file size, or greater hardware support by
  # passing a configuration based on your specific GPU environment.
  #
  # cudaCapabilities :: List Capability
  # List of hardware generations to build.
  # E.g. [ "8.0" ]
  # Currently, the last item is considered the optional forward-compatibility arch,
  # but this may change in the future.
  #
  # cudaForwardCompat :: Bool
  # Whether to include the forward compatibility gencode (+PTX)
  # to support future GPU generations.
  # E.g. true
  #
  # Please see the accompanying documentation or https://github.com/NixOS/nixpkgs/pull/205351

  # supportedGpus :: List GpuInfo
  # GPUs which are supported by the provided CUDA version.
  supportedGpus = filter (gpuIsSupported cudaMajorMinorVersion) (attrValues gpus);

  # defaultGpus :: List GpuInfo
  # GPUs which are supported by the provided CUDA version and we want to build for by default.
  defaultGpus = filter (gpuIsDefault cudaMajorMinorVersion) supportedGpus;

  # supportedCapabilities :: List Capability
  supportedCapabilities = map (gpu: gpu.cudaCapability) supportedGpus;

  # defaultCapabilities :: List Capability
  # The default capabilities to target, if not overridden by the user.
  defaultCapabilities = map (gpu: gpu.cudaCapability) defaultGpus;

  # cudaArchNameToVersions :: AttrSet String (List String)
  # Maps the name of a GPU architecture to different versions of that architecture.
  # For example, "Ampere" maps to [ "8.0" "8.6" "8.7" ].
  cudaArchNameToVersions = groupBy' (versions: gpu: versions ++ [ gpu.cudaCapability ]) [ ] (
    gpu: gpu.archName
  ) (attrValues gpus);

  # cudaCapabilityToName :: AttrSet String String
  # Maps the version of a GPU architecture to the name of that architecture.
  # For example, "8.0" maps to "Ampere".
  cudaCapabilityToName = mapAttrs (_: gpu: gpu.archName) gpus;

  # cudaCapabilityToIsJetson :: AttrSet String Boolean
  cudaCapabilityToIsJetson = mapAttrs (_: gpu: gpu.isJetson) gpus;

  # cudaCapabilityToIsAccelerated :: AttrSet String Boolean
  cudaCapabilityToIsAccelerated = mapAttrs (_: gpu: gpu.isAccelerated) gpus;

  # jetsonComputeCapabilities :: List String
  jetsonComputeCapabilities = pipe cudaCapabilityToIsJetson [
    (filterAttrs (_: isJetson: isJetson))
    attrNames
  ];

  # acceleratedComputeCapabilities :: List String
  acceleratedComputeCapabilities = pipe cudaCapabilityToIsAccelerated [
    (filterAttrs (_: isAccelerated: isAccelerated))
    attrNames
  ];

  # Find the intersection with the user-specified list of cudaCapabilities.
  # NOTE: Jetson devices are never built by default because they cannot be targeted along with
  # non-Jetson devices and require an aarch64 host platform. As such, if they're present anywhere,
  # they must be in the user-specified cudaCapabilities.
  # NOTE: We don't need to worry about mixes of Jetson and non-Jetson devices here -- there's
  # sanity-checking for all that in below.
  jetsonTargets = intersectLists jetsonComputeCapabilities cudaCapabilities;

  # Similarly, we can find the intersection of accelerated devices, which are not built by default and require
  # special handling.
  acceleratedTargets = intersectLists acceleratedComputeCapabilities cudaCapabilities;

  formatCapabilities =
    {
      cudaCapabilities,
      cudaForwardCompat ? true,
    }:
    let
      # realArches :: List String
      # The real architectures are physical architectures supported by the CUDA version.
      # E.g. [ "sm_75" "sm_86" ]
      realArches = map mkRealArchitecture cudaCapabilities;

      # virtualArches :: List String
      # The virtual architectures are typically used for forward compatibility, when trying to support
      # an architecture newer than the CUDA version allows.
      # E.g. [ "compute_75" "compute_86" ]
      virtualArches = map mkVirtualArchitecture cudaCapabilities;

      # gencode :: List String
      # A list of CUDA gencode arguments to pass to NVCC.
      # E.g. [ "-gencode=arch=compute_75,code=sm_75" ... "-gencode=arch=compute_86,code=compute_86" ]
      gencode =
        let
          base = map (mkGencodeFlag true) cudaCapabilities;
          forward = mkGencodeFlag false (last cudaCapabilities);
        in
        base ++ optionals cudaForwardCompat [ forward ];
    in
    {
      inherit
        cudaCapabilities
        cudaForwardCompat
        gencode
        realArches
        virtualArches
        ;

      # archNames :: List String
      # E.g. [ "Turing" "Ampere" ]
      #
      # Unknown architectures are rendered as sm_XX gencode flags.
      archNames = unique (
        map (
          cudaCapability: cudaCapabilityToName.${cudaCapability} or (mkRealArchitecture cudaCapability)
        ) cudaCapabilities
      );

      # arches :: List String
      # By default, build for all supported architectures and forward compatibility via a virtual
      # architecture for the newest supported architecture.
      # E.g. [ "sm_75" "sm_86" "compute_86" ]
      arches = realArches ++ optionals cudaForwardCompat [ (last virtualArches) ];

      # gencodeString :: String
      # A space-separated string of CUDA gencode arguments to pass to NVCC.
      # E.g. "-gencode=arch=compute_75,code=sm_75 ... -gencode=arch=compute_86,code=compute_86"
      gencodeString = concatStringsSep " " gencode;

      # cmakeCudaArchitecturesString :: String
      # A semicolon-separated string of CUDA capabilities without dots, suitable for passing to CMake.
      # E.g. "75;86"
      cmakeCudaArchitecturesString = mkCmakeCudaArchitecturesString cudaCapabilities;

      # Jetson devices cannot be targeted by the same binaries which target non-Jetson devices. While
      # NVIDIA provides both `linux-aarch64` and `linux-sbsa` packages, which both target `aarch64`,
      # they are built with different settings and cannot be mixed.
      # isJetsonBuild :: Boolean
      isJetsonBuild =
        let
          requestedJetsonDevices = filter (
            cudaCapability: cudaCapabilityToIsJetson.${cudaCapability} or false
          ) cudaCapabilities;
          requestedNonJetsonDevices = filter (
            cudaCapability: !(elem cudaCapability requestedJetsonDevices)
          ) cudaCapabilities;
          jetsonBuildSufficientCondition = requestedJetsonDevices != [ ];
          jetsonBuildNecessaryCondition = requestedNonJetsonDevices == [ ] && hostPlatform.isAarch64;
        in
        throwIf (jetsonBuildSufficientCondition && !jetsonBuildNecessaryCondition) ''
          Jetson devices cannot be targeted with non-Jetson devices. Additionally, they require hostPlatform to be aarch64.
          You requested ${toJSON cudaCapabilities} for host platform ${hostPlatform.system}.
          Requested Jetson devices: ${toJSON requestedJetsonDevices}.
          Requested non-Jetson devices: ${toJSON requestedNonJetsonDevices}.
          Exactly one of the following must be true:
          - All CUDA capabilities belong to Jetson devices and hostPlatform is aarch64.
          - No CUDA capabilities belong to Jetson devices.
          See gpus.nix for a list of architectures supported by this version of Nixpkgs.
        '' jetsonBuildSufficientCondition
        && jetsonBuildNecessaryCondition;

      # Accelerated devices are not built by default and cannot be built with other capabilities.
      isAcceleratedBuild =
        let
          requestedAcceleratedDevices = filter (
            cudaCapability: cudaCapabilityToIsAccelerated.${cudaCapability} or false
          ) cudaCapabilities;
          requestedNonAcceleratedDevices = filter (
            cudaCapability: !(elem cudaCapability requestedAcceleratedDevices)
          ) cudaCapabilities;
          acceleratedBuildSufficientCondition = length requestedAcceleratedDevices == 1;
          acceleratedBuildNecessaryCondition = requestedNonAcceleratedDevices == [ ];
        in
        throwIf (acceleratedBuildSufficientCondition && !acceleratedBuildNecessaryCondition) ''
          Accelerated devices cannot be targeted with non-accelerated devices.
          You requested ${toJSON cudaCapabilities}.
          Requested accelerated devices: ${toJSON requestedAcceleratedDevices}.
          Requested non-accelerated devices: ${toJSON requestedNonAcceleratedDevices}.
          Exactly one of the following must be true:
          - Exactly one CUDA capability is provided and is accelerated.
          - No CUDA capabilities are accelerated.
          See gpus.nix for a list of architectures supported by this version of Nixpkgs.
        '' acceleratedBuildSufficientCondition
        && acceleratedBuildNecessaryCondition;
    };
in
dontRecurseIntoAttrs {
  # formatCapabilities :: { cudaCapabilities: List Capability, cudaForwardCompat: Boolean } ->  { ... }
  inherit formatCapabilities;

  # cudaArchNameToVersions :: String => String
  inherit cudaArchNameToVersions;

  # cudaCapabilityToName :: String => String
  inherit cudaCapabilityToName;

  # dropDots :: String -> String
  inherit dropDots;

  # TODO: ALIAS
  dropDot = dropDots;

  inherit
    defaultCapabilities
    supportedCapabilities
    jetsonComputeCapabilities
    jetsonTargets
    acceleratedComputeCapabilities
    acceleratedTargets
    ;
}
// formatCapabilities {
  inherit cudaForwardCompat;
  cudaCapabilities = if cudaCapabilities == [ ] then defaultCapabilities else cudaCapabilities;
}
