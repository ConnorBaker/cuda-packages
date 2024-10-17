{
  config,
  cuda-lib,
  cudaOlder,
  cuda_cudart,
  cudnn,
  cudaMajorMinorVersion,
  flags,
  lib,
  libcudla,
  patchelf,
  stdenv,
}:
let
  inherit (cuda-lib.utils) getRedistArch majorMinorPatch;
  inherit (lib.attrsets) getLib;
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe';
  inherit (lib.strings) concatStringsSep optionalString;
  hostRedistArch = getRedistArch (config.data.jetsonTargets != [ ]) stdenv.hostPlatform.system;
in
finalAttrs: prevAttrs: {
  allowFHSReferences = true;

  badPlatformsConditions = prevAttrs.badPlatformsConditions // {
    "Unsupported platform" = hostRedistArch == "unsupported";
  };

  buildInputs =
    prevAttrs.buildInputs
    ++ [
      (getLib cudnn)
      cuda_cudart
    ]
    ++ optionals flags.isJetsonBuild [ libcudla ];

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
    # The CUDNN used with TensorRT.
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
