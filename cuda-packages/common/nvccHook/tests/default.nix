{
  autoPatchelfHook,
  cuda_cudart,
  cuda_nvcc,
  lib,
  nvccHook,
  patchelf,
  runCommand,
  stdenv,
  testers,
}:
let
  cApplication = stdenv.mkDerivation {
    # NOTE: Must set name!
    strictDeps = true;
    src = null;
    dontUnpack = true;
    buildPhase = ''
      runHook preBuild
      echo "int main() { return 0; }" > main.c
      cc main.c -o main
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      cp main "$out/bin/"
      runHook postInstall
    '';
  };

  args = {
    inherit
      autoPatchelfHook
      cApplication
      lib
      nvccHook
      patchelf
      runCommand
      stdenv
      testers
      ;
  };

  args-structuredAttrs = args // {
    cApplication = cApplication.overrideAttrs { __structuredAttrs = true; };
    __structuredAttrs = true; # For dontCompressCudaFatbin.nix
  };
in
{
  # Tests for dontCompressCudaFatbin option.
  dontCompressCudaFatbin = import ./dontCompressCudaFatbin.nix args;

  # TODO: Remove this when __structuredAttrs is enabled by default.
  dontCompressCudaFatbin-structuredAttrs = import ./dontCompressCudaFatbin.nix args-structuredAttrs;

  # Tests for nvccRunpathCheck.
  nvccRunpathCheck = import ./nvccRunpathCheck.nix args;

  # TODO: Remove this when __structuredAttrs is enabled by default.
  nvccRunpathCheck-structuredAttrs = import ./nvccRunpathCheck.nix args-structuredAttrs;

  # Tests for nvccHookOrderCheckPhase.
  nvccHookOrderCheckPhase = import ./nvccHookOrderCheckPhase.nix args;

  # TODO: Remove this when __structuredAttrs is enabled by default.
  nvccHookOrderCheckPhase-structuredAttrs = import ./nvccHookOrderCheckPhase.nix args-structuredAttrs;
}
