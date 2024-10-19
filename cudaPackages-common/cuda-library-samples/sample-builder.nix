# TODO(@connorbaker): Cleanup.
{
  backendStdenv,
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cudaMajorMinorVersion,
  fetchFromGitHub,
  flags,
  lib,
}:
overrideAttrsFn:
let
  basePkg = backendStdenv.mkDerivation (finalAttrs: {
    __structuredAttrs = true;
    strictDeps = true;

    name = "cuda${cudaMajorMinorVersion}-${finalAttrs.pname}-${finalAttrs.version}";
    pname = "cuda-library-samples-${finalAttrs.sampleName}";
    version = "0-unstable-2024-10-15";

    src = fetchFromGitHub {
      owner = "NVIDIA";
      repo = "CUDALibrarySamples";
      rev = "6ae31321042c3ab1d1041bf7196d98018bdb52e6";
      hash = "sha256-9KP+Lf78nHLtO9yhENcTlbRsjSV7tER2bpEhkzFNVzA=";
    };

    nativeBuildInputs = [
      cmake
      cuda_nvcc
    ];

    buildInputs = [ cuda_cudart ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      install -Dm755 \
        $(find . -type f -name "${finalAttrs.installExecutablesMatchingPattern}" -executable) \
        "$out/bin"
      runHook postInstall
    '';

    meta = {
      description = "examples of using libraries using CUDA";
      longDescription = ''
        CUDA Library Samples contains examples demonstrating the use of
        features in the math and image processing libraries cuBLAS, cuTENSOR,
        cuSPARSE, cuSOLVER, cuFFT, cuRAND, NPP and nvJPEG.
      '';
      license = lib.licenses.bsd3;
      maintainers = with lib.maintainers; [ obsidian-systems-maintenance ] ++ lib.teams.cuda.members;
    };
  });

  pkg = basePkg.overrideAttrs overrideAttrsFn;
in
pkg
