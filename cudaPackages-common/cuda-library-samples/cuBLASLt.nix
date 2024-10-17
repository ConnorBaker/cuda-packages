{
  cuda-library-samples,
  libcublas,
}:
cuda-library-samples.sample-builder (
  finalAttrs: prevAttrs: {
    sampleName = "cuBLASLt";
    sourceRoot = "source/${finalAttrs.sampleName}";
    installExecutablesMatchingPattern = "sample_*";
    # /build/cuBLASLt/LtIgemmTensor/main.cpp:38:45: error: narrowing conversion of '0.0f' from 'float' to 'int'
    #     38 |     TestBench<int8_t, int32_t> props(4, 4, 4);
    env.NIX_CFLAGS_COMPILE = toString [ "-Wno-narrowing" ];
    buildInputs = prevAttrs.buildInputs or [ ] ++ [
      libcublas
    ];
  }
)
