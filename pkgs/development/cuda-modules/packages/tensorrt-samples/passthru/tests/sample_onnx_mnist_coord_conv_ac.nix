{
  backendStdenv,
  lib,
  mkTest,
  sample-data,
  ...
}:
# TODO: Neither the sample data nor the sample sources provide mnist_with_coordconv.onnx, so we can't run these tests.
lib.optionalAttrs false {
  default = mkTest "sample_onnx_mnist_coord_conv_ac" [
    "sample_onnx_mnist_coord_conv_ac"
    "--datadir=${sample-data.outPath + "/mnist"}"
  ];

  int8 = mkTest "sample_onnx_mnist_coord_conv_ac-int8" [
    "sample_onnx_mnist_coord_conv_ac"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--int8"
  ];

  fp16 = mkTest "sample_onnx_mnist_coord_conv_ac-fp16" [
    "sample_onnx_mnist_coord_conv_ac"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--fp16"
  ];
}
# Only Orin has a DLA
// lib.optionalAttrs (false && lib.elem "8.7" backendStdenv.cudaCapabilities) {
  dla = mkTest "sample_onnx_mnist_coord_conv_ac-dla" [
    "sample_onnx_mnist_coord_conv_ac"
    "--datadir=${sample-data.outPath + "/mnist"}"
    "--useDLACore=0"
  ];
}
