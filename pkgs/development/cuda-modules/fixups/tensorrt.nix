{
  _cuda,
  backendStdenv,
  cuda_cudart,
  cudnn,
  cuda_nvrtc,
  lib,
  libcudla ? null, # only for Jetson
  patchelf,
  stdenv,
}:
let
  inherit (_cuda.lib) majorMinorPatch;
  inherit (backendStdenv) hasJetsonCudaCapability;
  inherit (lib.attrsets) getLib;
  inherit (lib.lists) optionals;
  inherit (lib.strings) concatStringsSep;
in
finalAttrs: prevAttrs:
let
  majorMinorPatchVersion = majorMinorPatch finalAttrs.version;
  majorVersion = lib.versions.major finalAttrs.version;
in
{
  allowFHSReferences = true;

  nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [ patchelf ];

  buildInputs =
    prevAttrs.buildInputs or [ ]
    ++ [
      (getLib cudnn)
      (getLib cuda_nvrtc)
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
        nixLog "replacing symlink $NIX_BUILD_TOP/$sourceRoot/$dir with $NIX_BUILD_TOP/$sourceRoot/targets/${targetString}/$dir"
        rm --verbose "$NIX_BUILD_TOP/$sourceRoot/$dir"
        mv --verbose --no-clobber "$NIX_BUILD_TOP/$sourceRoot/targets/${targetString}/$dir" "$NIX_BUILD_TOP/$sourceRoot/$dir"
      done
      unset -v dir
    ''
    # Remove symlinks if they exist
    + ''
      for dir in include samples; do
        if [[ -L "$NIX_BUILD_TOP/$sourceRoot/targets/${targetString}/$dir" ]]; then
          nixLog "removing symlink $NIX_BUILD_TOP/$sourceRoot/targets/${targetString}/$dir"
          rm --verbose "$NIX_BUILD_TOP/$sourceRoot/targets/${targetString}/$dir"
        fi
      done
      unset -v dir

      if [[ -d "$NIX_BUILD_TOP/$sourceRoot/targets" ]]; then
        nixLog "removing targets directory"
        rm --recursive --verbose "$NIX_BUILD_TOP/$sourceRoot/targets" || {
          nixErrorLog "could not delete $NIX_BUILD_TOP/$sourceRoot/targets: $(ls -laR "$NIX_BUILD_TOP/$sourceRoot/targets")"
          exit 1
        }
      fi
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
      mkdir "''${!outputInclude:?}/include/onnx"
      pushd "''${!outputInclude:?}/include" >/dev/null
      nixLog "creating symlinks for Onnx header files"
      ln -srvt "''${!outputInclude:?}/include/onnx/" NvOnnx*.h
      popd >/dev/null
    ''
    # Move the python directory, which contains header files, to the include output.
    + ''
      nixLog "moving python directory to include output"
      moveToOutput python "''${!outputInclude:?}"

      nixLog "remove python wheels"
      rm --verbose "''${!outputInclude:?}"/python/*.whl
    ''
    + ''
      nixLog "moving data directory to samples output"
      moveToOutput data "''${!outputSamples:?}"
    ''
    # Remove the Windows library used for cross-compilation if it exists.
    + ''
      if [[ -e "''${!outputLib:?}/lib/libnvinfer_builder_resource_win.so.${majorMinorPatchVersion}" ]]; then
        nixLog "removing Windows library"
        rm --verbose "''${!outputLib:?}/lib/libnvinfer_builder_resource_win.so.${majorMinorPatchVersion}"
      fi
    ''
    # Remove the stub libraries.
    + ''
      nixLog "removing stub libraries"
      rm --recursive --verbose "''${!outputLib:?}/lib/stubs" || {
        nixErrorLog "could not delete ''${!outputLib:?}/lib/stubs"
        exit 1
      }
    '';

  # Tell autoPatchelf about runtime dependencies.
  postFixup =
    prevAttrs.postFixup or ""
    + ''
      nixLog "patchelf-ing ''${!outputBin:?}/bin/trtexec with runtime dependencies"
      patchelf \
        "''${!outputBin:?}/bin/trtexec" \
        --add-needed libnvinfer_plugin.so.${majorVersion}
    '';

  passthru = prevAttrs.passthru or { } // {
    # The CUDNN used with TensorRT.
    inherit cudnn;

    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "bin"
        "dev"
        "include"
        "lib"
        "samples"
        "static"
        # "stubs" removed in postInstall
      ];
    };
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
