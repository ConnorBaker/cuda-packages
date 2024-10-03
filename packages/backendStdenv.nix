{
  config,
  cudaVersion,
  lib,
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
  cudaHostCompilerMajorVersion =
    config.data.nvccCompatibilities.${cudaVersion}.${hostCompiler}.maxMajorVersion;
  cudaHostStdenv =
    if hostCompiler == "clang" then
      pkgs."llvmPackages_${cudaHostCompilerMajorVersion}".stdenv
    else
      pkgs."gcc${cudaHostCompilerMajorVersion}Stdenv";
  # Always use libs from the default stdenv, as the rest of Nixpkgs will use them and we want to avoid conflicts
  # caused by having multiple versions of glibc available and in use.
  cudaStdenv = stdenvAdapters.useLibsFrom stdenv cudaHostStdenv;
  passthruExtra = {
    inherit cudaHostStdenv;
  };
  assertCondition = true;
in

# TODO: Consider testing whether we in fact use the newer libstdc++
extendDerivation assertCondition passthruExtra cudaStdenv
