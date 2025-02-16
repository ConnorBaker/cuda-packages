{

  cuda_cudart,
  cudaLib,
  cudaPackagesConfig,
  cudnn,
  lib,
  libcudla ? null, # only for Jetson
  patchelf,
  stdenv,
}:
let
  inherit (cudaPackagesConfig) hasJetsonCudaCapability;
  inherit (cudaLib.utils) majorMinorPatch;
  inherit (lib.attrsets) getLib;
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe;
  inherit (lib.strings) concatStringsSep;
in
finalAttrs: prevAttrs: {
  allowFHSReferences = true;

  buildInputs =
    prevAttrs.buildInputs or [ ]
    ++ [
      (getLib cudnn)
      cuda_cudart
    ]
    ++ optionals hasJetsonCudaCapability [ libcudla ];

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
    prevAttrs.preInstall or ""
    # Replace symlinks to bin and lib with the actual directories from targets.
    + ''
      for dir in bin lib; do
        [[ -L "$dir" ]] || continue
        nixLog "replacing symlink $dir with targets/${targetString}/$dir"
        rm "$dir"
        mv "targets/${targetString}/$dir" "$dir"
      done
    ''
    # Remove symlinks if they exist
    + ''
      for dir in include samples; do
        if [[ -L "targets/${targetString}/$dir" ]]; then
          nixLog "removing symlink targets/${targetString}/$dir"
          rm "targets/${targetString}/$dir"
        fi
      done
    '';

  autoPatchelfIgnoreMissingDeps =
    prevAttrs.autoPatchelfIgnoreMissingDeps or [ ]
    ++ optionals hasJetsonCudaCapability [
      "libnvdla_compiler.so"
    ];

  postInstall =
    prevAttrs.postInstall or ""
    # Create a symlink for the Onnx header files in include/onnx
    # NOTE(@connorbaker): This is shared with the tensorrt-oss package, with the `out` output swapped with `include`.
    # When updating one, check if the other should be updated.
    + ''
      mkdir "$include/include/onnx"
      pushd "$include/include"
      nixLog "creating symlinks for Onnx header files"
      ln -srt "$include/include/onnx/" NvOnnx*.h
      popd
    ''
    # Move the python directory, which contains header files to the include output.
    + ''
      nixLog "moving python directory to include output"
      mv "$out/python" "$include/python"
    '';

  # Tell autoPatchelf about runtime dependencies.
  postFixup =
    let
      versionTriple = majorMinorPatch finalAttrs.version;
    in
    prevAttrs.postFixup or ""
    + ''
      "${getExe patchelf}" --add-needed libnvinfer.so \
        "$lib/lib/libnvinfer.so.${versionTriple}" \
        "$lib/lib/libnvinfer_plugin.so.${versionTriple}" \
        "$lib/lib/libnvinfer_builder_resource.so.${versionTriple}"
    '';

  passthru = prevAttrs.passthru or { } // {
    # The CUDNN used with TensorRT.
    inherit cudnn;
  };

  meta = prevAttrs.meta or { } // {
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
