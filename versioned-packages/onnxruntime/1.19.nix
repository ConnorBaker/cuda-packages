{
  callPackage,
  fetchFromGitHub,
  flatbuffers_23,
  onnx_1_16,
  onnx-tensorrt_10_4,
  protobuf_21,
  tensorrt_10_4,
}:
callPackage ./generic.nix {
  version = "1.19.2";
  hash = "sha256-LLTPDvdWdK+2yo7uRVzjEQOEmc2ISEQ1Hp2SZSYSpSU=";

  # Package overrides
  onnx = onnx_1_16;
  onnx-tensorrt = onnx-tensorrt_10_4;
  flatbuffers = flatbuffers_23;
  protobuf = protobuf_21;
  tensorrt = tensorrt_10_4;

  # Sources
  cutlass = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cutlass";
    rev = "refs/tags/v3.5.0";
    hash = "sha256-D/s7eYsa5l/mfx73tE4mnFcTQdYqGmXa9d9TCryw4e4=";
  };
}
