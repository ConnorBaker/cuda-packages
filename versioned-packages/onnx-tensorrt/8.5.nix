{
  callPackage,
  onnx_1_12,
  protobuf_21,
  tensorrt_8_5,
}:
callPackage ./generic.nix {
  version = "8.5";
  hash = "sha256-UPFHw4ode+RNog2c665u2wjNhjMn6Y3dl7wiw6HptlM=";
  onnx = onnx_1_12;
  protobuf = protobuf_21;
  tensorrt = tensorrt_8_5;
}
