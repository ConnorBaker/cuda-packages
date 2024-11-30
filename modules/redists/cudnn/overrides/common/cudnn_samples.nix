{
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cudnn,
  lib,
}:
let
  inherit (lib.versions) major;
in
prevAttrs:
let
  cudnnSamplesMajorVersion = major prevAttrs.version;
in
{
  allowFHSReferences = true;

  # Sources are nested in a directory with the same name as the package
  setSourceRoot = "sourceRoot=$(echo */src/cudnn_samples_v${cudnnSamplesMajorVersion}/)";

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
  };
}
