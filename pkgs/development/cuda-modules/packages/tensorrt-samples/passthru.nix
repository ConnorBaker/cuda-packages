{
  fetchzip,
  finalAttrs,
  lib,
  stdenvNoCC,
}:
let
  older = lib.versionOlder finalAttrs.version;
  atLeast = lib.versionAtLeast finalAttrs.version;

  mkTest =
    name: cmdArgs:
    stdenvNoCC.mkDerivation {
      __structuredAttrs = true;

      strictDeps = true;

      name = finalAttrs.name + "-" + name;

      inherit cmdArgs;

      nativeBuildInputs = [
        finalAttrs.finalPackage
      ];

      dontUnpack = true;

      dontConfigure = true;

      buildPhase = ''
        runHook preBuild

        nixLog "running ''${cmdArgs[*]@Q}"
        mkdir -p "$out"
        "''${cmdArgs[@]}" | tee -a "$out/test.log" || {
          nixErrorLog "command failed with exit code $?"
          exit 1
        }

        runHook postBuild
      '';

      installPhase = ''
        touch "$out"
      '';

      requiredSystemFeatures = [ "cuda" ];
    };
in
{
  sample-data =
    let
      # Releases prior to 10.14.1 don't have any sample data available to them, so just use the 10.14.1 release's
      # sample data.
      sample-data_10_14_1 = {
        url = "https://github.com/NVIDIA/TensorRT/releases/download/v10.14/tensorrt_sample_data_20251106.zip";
        hash = "sha256-IA1pH8idtk/7FD1Tf0hKtyP7A5SW/2ugezyBRluG8yk=";
      };
    in
    fetchzip (
      if older "10.14.1" then
        sample-data_10_14_1
      else
        lib.getAttr finalAttrs.version {
          "10.14.1" = sample-data_10_14_1;
        }
    );

  # TODO: A number of the tests fail with 10.2:
  # API Usage Error (Unable to load library: libnvinfer_builder_resource_win.so.10.2.0:
  # libnvinfer_builder_resource_win.so.10.2.0: cannot open shared object file: No such file or directory)
  tests = {
    sample_char_rnn = mkTest "sample_char_rnn" [
      "sample_char_rnn"
      "--datadir"
      (finalAttrs.passthru.sample-data.outPath + "/char-rnn")
    ];

    sample_dynamic_reshape = mkTest "sample_dynamic_reshape" [
      "sample_dynamic_reshape"
      "--datadir"
      (finalAttrs.passthru.sample-data.outPath + "/mnist")
    ];
    # TODO: Neither the sample data nor the sample sources provide train-images-idx3-ubyte, so we can't run the int8 test.
    # sample_dynamic_reshape-int8 = mkTest "sample_dynamic_reshape-int8" [
    #   "sample_dynamic_reshape"
    #   "--datadir"
    #   (finalAttrs.passthru.sample-data.outPath + "/mnist")
    #   "--int8"
    # ];
    sample_dynamic_reshape-fp16 = mkTest "sample_dynamic_reshape-fp16" [
      "sample_dynamic_reshape"
      "--datadir"
      (finalAttrs.passthru.sample-data.outPath + "/mnist")
      "--fp16"
    ];
    sample_dynamic_reshape-bf16 = mkTest "sample_dynamic_reshape-bf16" [
      "sample_dynamic_reshape"
      "--datadir"
      (finalAttrs.passthru.sample-data.outPath + "/mnist")
      "--bf16"
    ];
  }
  // lib.optionalAttrs (atLeast "10.8") {
    sample_editable_timing_cache = mkTest "sample_editable_timing_cache" [
      "sample_editable_timing_cache"
    ];
  }
  // {
    # TODO: Test DLA on Jetson Orin.
    # --useDLACore=N. Specify a DLA engine for layers that support DLA. Value can range from 0 to n-1, where n is the number of DLA engines on the platform.
    sample_int8_api = mkTest "sample_int8_api" [
      "sample_int8_api"
      "--model=${finalAttrs.passthru.sample-data.outPath + "/resnet50/ResNet50.onnx"}"
      "--data=${finalAttrs.passthru.sample-data.outPath + "/int8_api"}"
    ];

    # TODO: Test DLA on Jetson Orin.
    # --useDLACore=N     Specify a DLA engine for layers that support DLA. Value can range from 0 to n-1, where n is the number of DLA engines on the platform.
    sample_io_formats = mkTest "sample_io_formats" [
      "sample_io_formats"
      "--datadir"
      (finalAttrs.passthru.sample-data.outPath + "/mnist")
    ];

    sample_named_dimensions = mkTest "sample_named_dimensions" [
      "sample_named_dimensions"
      "--datadir"
      (finalAttrs.src.outPath + "/samples/sampleNamedDimensions")
    ];

    sample_non_zero_plugin = mkTest "sample_non_zero_plugin" [
      "sample_non_zero_plugin"
      "--datadir"
      (finalAttrs.passthru.sample-data.outPath + "/mnist")
    ];
    sample_non_zero_plugin-fp16 = mkTest "sample_non_zero_plugin-fp16" [
      "sample_non_zero_plugin"
      "--datadir"
      (finalAttrs.passthru.sample-data.outPath + "/mnist")
      "--fp16"
    ];
  }
  // lib.optionalAttrs (atLeast "10.1") {
    sample_non_zero_plugin-columnOrder = mkTest "sample_non_zero_plugin-columnOrder" [
      "sample_non_zero_plugin"
      "--datadir"
      (finalAttrs.passthru.sample-data.outPath + "/mnist")
      "--columnOrder"
    ];
  }
  // {
    # TODO: Test DLA on Jetson Orin.
    # --useDLACore=N     Specify a DLA engine for layers that support DLA. Value can range from 0 to n-1, where n is the number of DLA engines on the platform.
    sample_onnx_mnist = mkTest "sample_onnx_mnist" [
      "sample_onnx_mnist"
      "--datadir"
      (finalAttrs.passthru.sample-data.outPath + "/mnist")
    ];
    sample_onnx_mnist-int8 = mkTest "sample_onnx_mnist-int8" [
      "sample_onnx_mnist"
      "--datadir"
      (finalAttrs.passthru.sample-data.outPath + "/mnist")
      "--int8"
    ];
    sample_onnx_mnist-fp16 = mkTest "sample_onnx_mnist-fp16" [
      "sample_onnx_mnist"
      "--datadir"
      (finalAttrs.passthru.sample-data.outPath + "/mnist")
      "--fp16"
    ];
    sample_onnx_mnist-bf16 = mkTest "sample_onnx_mnist-bf16" [
      "sample_onnx_mnist"
      "--datadir"
      (finalAttrs.passthru.sample-data.outPath + "/mnist")
      "--bf16"
    ];

    # TODO: Neither the sample data nor the sample sources provide mnist_with_coordconv.onnx, so we can't run these tests.
    # TODO: Test DLA on Jetson Orin.
    # --useDLACore=N     Specify a DLA engine for layers that support DLA. Value can range from 0 to n-1, where n is the number of DLA engines on the platform.
    # sample_onnx_mnist_coord_conv_ac = mkTest "sample_onnx_mnist_coord_conv_ac" [
    #   "sample_onnx_mnist_coord_conv_ac"
    #   "--datadir"
    #   (finalAttrs.passthru.sample-data.outPath + "/mnist")
    # ];
    # sample_onnx_mnist_coord_conv_ac-int8 = mkTest "sample_onnx_mnist_coord_conv_ac-int8" [
    #   "sample_onnx_mnist_coord_conv_ac"
    #   "--datadir"
    #   (finalAttrs.passthru.sample-data.outPath + "/mnist")
    #   "--int8"
    # ];
    # sample_onnx_mnist_coord_conv_ac-fp16 = mkTest "sample_onnx_mnist_coord_conv_ac-fp16" [
    #   "sample_onnx_mnist_coord_conv_ac"
    #   "--datadir"
    #   (finalAttrs.passthru.sample-data.outPath + "/mnist")
    #   "--fp16"
    # ];

    # NOTE: Disabled because it generates way too much output.
    # TODO: Test DLA on Jetson Orin.
    # --useDLACore=N     Specify a DLA engine for layers that support DLA. Value can range from 0 to n-1, where n is the number of DLA engines on the platform.
    # sample_progress_monitor = mkTest "sample_progress_monitor" [
    #   "sample_progress_monitor"
    #   "--datadir"
    #   (finalAttrs.passthru.sample-data.outPath + "/mnist")
    # ];
    # sample_progress_monitor-int8 = mkTest "sample_progress_monitor-int8" [
    #   "sample_progress_monitor"
    #   "--datadir"
    #   (finalAttrs.passthru.sample-data.outPath + "/mnist")
    #   "--int8"
    # ];
    # sample_progress_monitor-fp16 = mkTest "sample_progress_monitor-fp16" [
    #   "sample_progress_monitor"
    #   "--datadir"
    #   (finalAttrs.passthru.sample-data.outPath + "/mnist")
    #   "--fp16"
    # ];

    # trtexec
  };
}
