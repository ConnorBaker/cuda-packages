{
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cuda-lib,
  cudaPackages,
  lib,
}:
let
  inherit (lib.versions) major;
in
prevAttrs:
let
  desiredCudnnName = cuda-lib.utils.mkVersionedPackageName {
    packageName = "cudnn";
    redistName = "cudnn";
    inherit (prevAttrs) version;
    versionPolicy = "minor";
  };
  desiredCudnn = cudaPackages.${desiredCudnnName} or null;
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

  badPlatformsConditions =
    prevAttrs.badPlatformsConditions
    // cuda-lib.utils.mkMissingPackagesBadPlatformsConditions {
      ${desiredCudnnName} = desiredCudnn;
    };

  nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
    cmake
    cuda_nvcc
  ];
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    cuda_cudart
    desiredCudnn
  ];
}
