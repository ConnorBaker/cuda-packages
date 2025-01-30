{
  autoAddDriverRunpath,
  autoPatchelfHook,
  cudaRunpathFixupHook,
  lib,
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
      autoAddDriverRunpath
      autoPatchelfHook
      cApplication
      cudaRunpathFixupHook
      lib
      patchelf
      runCommand
      testers
      ;
  };

  args-structuredAttrs = args // {
    cApplication = cApplication.overrideAttrs { __structuredAttrs = true; };
  };
in
{
  # Tests for cudaRunpathFixup.
  cudaRunpathFixup = import ./cudaRunpathFixup.nix args;

  # TODO: Remove this when __structuredAttrs is enabled by default.
  cudaRunpathFixup-structuredAttrs = import ./cudaRunpathFixup.nix args-structuredAttrs;

  # Tests for cudaRunpathFixupHookOrderCheckPhase.
  cudaRunpathFixupHookOrderCheckPhase = import ./cudaRunpathFixupHookOrderCheckPhase.nix args;

  # TODO: Remove this when __structuredAttrs is enabled by default.
  cudaRunpathFixupHookOrderCheckPhase-structuredAttrs = import ./cudaRunpathFixupHookOrderCheckPhase.nix args-structuredAttrs;
}
