{
  callPackage,
  fetchFromGitHub,
  abseil-cpp_202401,
  flatbuffers_23,
  onnx_1_16,
  onnx-tensorrt_10_4,
  protobuf_21,
  tensorrt_10_4,
}:
callPackage ./generic.nix {
  version = "1.18.2";
  hash = "sha256-Z9EezJ1WGd2g9XwXIjp1h/rn/a0JCahvOUUkZc+wKtQ=";

  # Package overrides
  abseil-cpp = abseil-cpp_202401;
  onnx = onnx_1_16;
  onnx-tensorrt = onnx-tensorrt_10_4;
  flatbuffers = flatbuffers_23;
  protobuf = protobuf_21;
  tensorrt = tensorrt_10_4;

  # Sources
  cutlass = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cutlass";
    rev = "refs/tags/v3.1.0";
    hash = "sha256-mpaiCxiYR1WaSSkcEPTzvcREenJWklD+HRdTT5/pD54=";
  };
}
