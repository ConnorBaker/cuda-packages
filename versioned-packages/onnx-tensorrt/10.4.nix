{
  callPackage,
  onnx_1_16,
  tensorrt_10_4,
}:
callPackage ./generic.nix {
  version = "10.4";
  hash = "sha256-ZHWIwPy/iQS6iKAxVL9kKM+KbfzvktFrCElie4Aj8mg=";
  onnx = onnx_1_16;
  tensorrt = tensorrt_10_4;
}
