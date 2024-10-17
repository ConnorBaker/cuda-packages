{
  config,
  cuda-lib,
  cudaOlder,
  cudaPackages,
  cudaMajorMinorVersion,
  flags,
  lib,
  libcudla ? null,
  patchelf,
  stdenv,
}:
let
  inherit (cuda-lib.utils) getRedistArch majorMinorPatch mkVersionedPackageName;
  inherit (lib.attrsets) attrByPath getLib optionalAttrs;
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe';
  inherit (lib.strings) concatStringsSep optionalString;
  hostRedistArch = getRedistArch (config.data.jetsonTargets != [ ]) stdenv.hostPlatform.system;
in
finalAttrs:
let
  constraints = attrByPath [
    finalAttrs.version
    hostRedistArch
  ] { } (builtins.import ./constraints.nix);
  cudnn =
    let
      desiredName = mkVersionedPackageName {
        packageName = "cudnn";
        redistName = "cudnn";
        version = constraints.cudnnMajorMinorPatchVersion;
        versionPolicy = "patch";
      };
    in
    cudaPackages.${desiredName} or cudaPackages.cudnn;

  cudaMismatch =
    constraints ? cudaMajorMinorVersion && cudaMajorMinorVersion != constraints.cudaMajorMinorVersion;
  cudnnMismatch =
    constraints ? cudnnMajorMinorPatchVersion
    && (majorMinorPatch cudnn.version) != constraints.cudnnMajorMinorPatchVersion;
in
prevAttrs: {
  allowFHSReferences = true;

  # Useful for inspecting why something went wrong.
  brokenConditions = prevAttrs.brokenConditions // {
    "CUDA version mismatch" = cudaMismatch;
    "CUDNN version mismatch" = cudnnMismatch;
  };

  badPlatformsConditions =
    prevAttrs.badPlatformsConditions
    # NOTE: For some reason, CUDA 12.3 is missing `libcudla`.
    // cuda-lib.utils.mkMissingPackagesBadPlatformsConditions (
      optionalAttrs flags.isJetsonBuild { inherit libcudla; }
    )
    // {
      "Unsupported platform" = hostRedistArch == "unsupported";
    };

  buildInputs =
    prevAttrs.buildInputs
    ++ [ (getLib cudnn) ]
    ++ optionals flags.isJetsonBuild [ libcudla ]
    ++ optionals finalAttrs.passthru.useCudatoolkitRunfile [ cudaPackages.cudatoolkit ]
    ++ optionals (!finalAttrs.passthru.useCudatoolkitRunfile) [ cudaPackages.cuda_cudart ];

  preInstall =
    let
      inherit (stdenv.hostPlatform) parsed;
      # x86_64-linux-gnu
      targetString = concatStringsSep "-" [
        parsed.cpu.name
        parsed.kernel.name
        parsed.abi.name
      ];
    in
    (prevAttrs.preInstall or "")
    + optionalString (hostRedistArch != "unsupported") ''
      # Replace symlinks to bin and lib with the actual directories from targets.
      for dir in bin lib; do
        # Only replace if the symlink exists.
        [ -L "$dir" ] || continue
        rm "$dir"
        mv "targets/${targetString}/$dir" "$dir"
      done
    '';

  autoPatchelfIgnoreMissingDeps = prevAttrs.autoPatchelfIgnoreMissingDeps ++ [
    "libnvdla_compiler.so"
  ];

  # Tell autoPatchelf about runtime dependencies.
  postFixup =
    let
      versionTriple = majorMinorPatch finalAttrs.version;
    in
    (prevAttrs.postFixup or "")
    + ''
      ${getExe' patchelf "patchelf"} --add-needed libnvinfer.so \
        "$lib/lib/libnvinfer.so.${versionTriple}" \
        "$lib/lib/libnvinfer_plugin.so.${versionTriple}" \
        "$lib/lib/libnvinfer_builder_resource.so.${versionTriple}"
    '';

  passthru = prevAttrs.passthru // {
    useCudatoolkitRunfile = cudaOlder "11.4";
    # The CUDNN used with TensorRT.
    # If null, the default cudnn derivation will be used.
    # If a version is specified, the cudnn derivation with that version will be used,
    # unless it is not available, in which case the default cudnn derivation will be used.
    inherit cudnn;
  };

  meta = prevAttrs.meta // {
    description = "TensorRT: An SDK for High-Performance Inference on NVIDIA GPUs";
    homepage = "https://developer.nvidia.com/tensorrt";
    maintainers = prevAttrs.meta.maintainers ++ [ lib.maintainers.aidalgol ];
    license = lib.licenses.unfreeRedistributable // {
      shortName = "TensorRT EULA";
      name = "TensorRT SUPPLEMENT TO SOFTWARE LICENSE AGREEMENT FOR NVIDIA SOFTWARE DEVELOPMENT KITS";
      url = "https://docs.nvidia.com/deeplearning/tensorrt/sla/index.html";
    };
  };
}
