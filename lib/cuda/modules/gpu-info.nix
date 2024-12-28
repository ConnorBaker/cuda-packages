{ lib }:
let
  inherit (lib.cuda.types) cudaCapability majorMinorVersion;
  inherit (lib.cuda.utils) mkOptionsModule;
  inherit (lib.types) bool nonEmptyStr nullOr;
in
{ name, ... }:
mkOptionsModule {
  archName = {
    description = "The name of the microarchitecture.";
    type = nonEmptyStr;
  };
  cudaCapability = {
    description = "The CUDA capability of the GPU.";
    type = cudaCapability;
    default = name;
  };
  dontDefaultAfterCudaMajorMinorVersion = {
    description = ''
      The CUDA version after which to exclude this GPU from the list of default capabilities we build.

      The value `null` means we always include this GPU in the default capabilities if it is supported.
    '';
    type = nullOr majorMinorVersion;
  };
  isJetson = {
    description = ''
      Whether a GPU is part of NVIDIA's line of Jetson embedded computers. This field is notable because it tells us
      what architecture to build for (as Jetson devices are aarch64).
      More on Jetson devices here: https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/
      NOTE: These architectures are only built upon request.
    '';
    type = bool;
  };
  maxCudaMajorMinorVersion = {
    description = ''
      The maximum (exclusive) CUDA version that supports this GPU. `null` means there is no maximum.
    '';
    type = nullOr majorMinorVersion;
  };
  minCudaMajorMinorVersion = {
    description = "The minimum (inclusive) CUDA version that supports this GPU.";
    type = majorMinorVersion;
  };
}
