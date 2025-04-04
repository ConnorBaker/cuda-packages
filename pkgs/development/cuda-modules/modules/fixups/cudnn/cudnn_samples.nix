{
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cudnn,
  lib,
}:
finalAttrs: prevAttrs: {
  allowFHSReferences = true;

  # Sources are nested in a directory with the same name as the package
  setSourceRoot = "sourceRoot=$(echo */src/cudnn_samples_v${lib.major finalAttrs.version}/)";

  nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
    cmake
    cuda_nvcc
  ];

  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    cuda_cudart
    cudnn
  ];

  passthru = prevAttrs.passthru or { } // {
    brokenConditions = prevAttrs.passthru.brokenConditions or { } // {
      "FreeImage is required as a subdirectory and @connorbaker has not yet patched the build to find it" =
        true;
    };

    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "dev"
        "include"
        "lib"
        "static"
      ];
    };
  };
}
