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
  gccMajorVersion = config.data.nvccCompatibilities.${cudaVersion}.gccMaxMajorVersion;
  # TODO(@connorbaker): Get numbers for why we should use stdenvAdapters.useMoldLinker.
  cudaStdenv = stdenvAdapters.useLibsFrom stdenv pkgs."gcc${gccMajorVersion}Stdenv";
  passthruExtra.withMoldLinker = stdenvAdapters.useMoldLinker cudaStdenv;
  assertCondition = true;
in

# TODO: Consider testing whether we in fact use the newer libstdc++

lib.extendDerivation assertCondition passthruExtra cudaStdenv
