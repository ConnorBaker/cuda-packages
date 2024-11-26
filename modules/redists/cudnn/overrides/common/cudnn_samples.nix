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

  brokenConditions = prevAttrs.brokenConditions // {
    "FreeImage is required as a subdirectory and @connorbaker has not yet patched the build to find it" =
      true;
  };

  nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
    cmake
    cuda_nvcc
  ];

  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    cuda_cudart
    cudnn
  ];
}
