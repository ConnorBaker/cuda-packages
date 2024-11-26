{

  cuda_cudart,
  cudnn,
  flags,
  lib,
  libcudla ? null, # only for Jetson
  patchelf,
  stdenv,
}:
let
  inherit (lib.cuda.utils) getRedistArch majorMinorPatch;
  inherit (lib.attrsets) getLib;
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe;
  inherit (lib.strings) concatStringsSep optionalString;
  hostRedistArch = getRedistArch (flags.jetsonTargets != [ ]) stdenv.hostPlatform.system;
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
    # Replace symlinks to bin and lib with the actual directories from targets.
    + optionalString (hostRedistArch != "unsupported") ''
      for dir in bin lib; do
        # Only replace if the symlink exists.
        [[ -L "$dir" ]] || continue
        rm "$dir"
        mv "targets/${targetString}/$dir" "$dir"
      done
    ''
    # Remove symlinks if they exist
    + ''
      for dir in include samples; do
        [[ -L "targets/${targetString}/$dir" ]] && rm "targets/${targetString}/$dir"
      done
    '';

  autoPatchelfIgnoreMissingDeps =
    prevAttrs.autoPatchelfIgnoreMissingDeps or [ ]
    ++ optionals flags.isJetsonBuild [
      "libnvdla_compiler.so"
    ];

  # Create a symlink for the Onnx header files in include/onnx
  # NOTE(@connorbaker): This is shared with the tensorrt-oss package, with the `out` output swapped with `include`.
  # When updating one, check if the other should be updated.
  postInstall =
    (prevAttrs.postInstall or "")
    + ''
      mkdir "$include/include/onnx"
      pushd "$include/include"
      ln -srt "$include/include/onnx/" NvOnnx*.h
      popd
    '';

  # Tell autoPatchelf about runtime dependencies.
  postFixup =
    let
      versionTriple = majorMinorPatch finalAttrs.version;
    in
    (prevAttrs.postFixup or "")
    + ''
      ${getExe patchelf} --add-needed libnvinfer.so \
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
