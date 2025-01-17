{
  config,
  cudaConfig,
  cudaMajorMinorVersion,
  lib,
  nixLogWithLevelAndFunctionNameHook,
  noBrokenSymlinksHook,
  path,
  stdenv,
}:
# Exposed as cudaPackages.cudaStdenv.
#
# Sets defaults for our package set.
let
  inherit (lib.customisation) extendDerivation;
  cudaNamePrefix = "cuda${cudaMajorMinorVersion}";

  # The following two utility functions are staken from stdenvAdapters. The second is inspired by
  # `propagateBuildInputs`, manually substituted and reduced.

  # N.B. Keep in sync with default arg for stdenv/generic.
  defaultMkDerivationFromStdenv =
    stdenv:
    (import (path + "/pkgs/stdenv/generic/make-derivation.nix") {
      inherit config lib;
    } stdenv).mkDerivation;

  mkCudaStdenv =
    stdenv:
    stdenv.override (
      stdenvPrevAttrs:
      let
        prevMkDerivationFromStdenv =
          stdenvPrevAttrs.mkDerivationFromStdenv or defaultMkDerivationFromStdenv;
      in
      {
        mkDerivationFromStdenv =
          stdenvFinal: args:
          (prevMkDerivationFromStdenv stdenvFinal args).overrideAttrs (mkDerivationPrevAttrs: {
            # Default __structuredAttrs and strictDeps to true.
            __structuredAttrs = mkDerivationPrevAttrs.__structuredAttrs or true;
            strictDeps = mkDerivationPrevAttrs.strictDeps or true;

            # Name should be prefixed by cudaNamePrefix to create more descriptive path names.
            name =
              if mkDerivationPrevAttrs ? pname && mkDerivationPrevAttrs ? version then
                "${cudaNamePrefix}-${mkDerivationPrevAttrs.pname}-${mkDerivationPrevAttrs.version}"
              else
                "${cudaNamePrefix}-${mkDerivationPrevAttrs.name}";

            propagatedBuildInputs = mkDerivationPrevAttrs.propagatedBuildInputs or [ ] ++ [
              # We add a hook to replace the standard logging functions.
              nixLogWithLevelAndFunctionNameHook
              # We add a hook to make sure we're not propagating broken symlinks.
              noBrokenSymlinksHook
            ];
          });
      }
    );

  passthruExtra = {
    inherit cudaNamePrefix;
    inherit (cudaConfig) hostRedistArch;
  };

  assertCondition = true;
in
extendDerivation assertCondition passthruExtra (mkCudaStdenv stdenv)
