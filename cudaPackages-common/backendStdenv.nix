{
  autoAddDriverRunpath,
  autoPatchelfHook,
  config,
  cudaVersion,
  lib,
  path,
  pkgs,
  stdenv,
  stdenvAdapters,
}:
# Exposed as cudaPackages.backendStdenv.
# This is what nvcc uses as a backend,
# and it has to be an officially supported one (e.g. gcc11 for cuda11).
#
# It, however, propagates current stdenv's libstdc++ to avoid "GLIBCXX_* not found errors"
# when linked with other C++ libraries.
# E.g. for cudaPackages_11_8 we use gcc11 with gcc12's libstdc++
# Cf. https://github.com/NixOS/nixpkgs/pull/218265 for context
let
  inherit (config.cuda) hostCompiler;
  inherit (lib.customisation) extendDerivation;
  inherit (stdenvAdapters) useLibsFrom;

  # The following two utility functions are staken from stdenvAdapters. The second is inspired by
  # `propagateBuildInputs`, manually substituted and reduced.

  # N.B. Keep in sync with default arg for stdenv/generic.
  defaultMkDerivationFromStdenv =
    stdenv:
    (import (path + "/pkgs/stdenv/generic/make-derivation.nix") {
      inherit (pkgs) config;
      inherit lib;
    } stdenv).mkDerivation;

  addPropagatedNativeBuildInputs =
    extraPropagatedNativeBuildInputs: stdenv:
    stdenv.override (
      stdenvPrevAttrs:
      let
        mkDerivationFromStdenv = stdenvPrevAttrs.mkDerivationFromStdenv or defaultMkDerivationFromStdenv;
      in
      {
        mkDerivationFromStdenv =
          stdenvFinal: args:
          (mkDerivationFromStdenv stdenvFinal args).overrideAttrs (mkDerivationPrevAttrs: {
            propagatedNativeBuildInputs =
              mkDerivationPrevAttrs.propagatedNativeBuildInputs or [ ] ++ extraPropagatedNativeBuildInputs;
          });
      }
    );

  cudaHostCompilerMajorVersion =
    config.data.nvccCompatibilities.${cudaVersion}.${hostCompiler}.maxMajorVersion;
  cudaHostStdenv =
    if hostCompiler == "clang" then
      pkgs."llvmPackages_${cudaHostCompilerMajorVersion}".stdenv
    else
      pkgs."gcc${cudaHostCompilerMajorVersion}Stdenv";

  cudaStdenv =
    # Two common footguns when building CUDA packages:
    # 1. Forgetting to use `autoAddDriverRunpath` so the libraries provided by the CUDA drivers are found at runtime.
    # 2. Missing dependencies `autoPatchelfHook` would have caught and warned about or corrected.
    addPropagatedNativeBuildInputs
      [
        autoAddDriverRunpath
        autoPatchelfHook
      ]
      # Always use libs from the default stdenv, as the rest of Nixpkgs will use them and we want to avoid conflicts
      # caused by having multiple versions of glibc available and in use.
      (useLibsFrom stdenv cudaHostStdenv);
  passthruExtra = {
    inherit cudaHostStdenv;
  };
  assertCondition = true;
in

# TODO: Consider testing whether we in fact use the newer libstdc++
extendDerivation assertCondition passthruExtra cudaStdenv
