{
  _cuda,
  arrayUtilities,
  autoFixElfFiles,
  backendStdenv,
  callPackages,
  config,
  cudaNamePrefix,
  lib,
  makeSetupHook,
  patchelf,
  stdenv,
}:
let
  inherit (_cuda.lib) _mkMetaBroken;
  inherit (backendStdenv) nvccHostCCMatchesStdenvCC;
  inherit (lib.attrsets) optionalAttrs;

  finalAttrs = {
    # NOTE: Depends on the CUDA package set, so use cudaNamePrefix.
    name = "${cudaNamePrefix}-nvccHook";

    propagatedBuildInputs = [
      arrayUtilities.arrayReplace
      arrayUtilities.getRunpathEntries
      autoFixElfFiles
      patchelf
    ];

    # TODO(@connorbaker): The setup hook tells CMake not to link paths which include a GCC-specific compiler
    # path from backendStdenv's host compiler. Generalize this to Clang as well!
    substitutions = {
      inherit nvccHostCCMatchesStdenvCC;
    }
    // optionalAttrs (!nvccHostCCMatchesStdenvCC) {
      backendStdenvCCVersion = backendStdenv.cc.version;
      backendStdenvCCHostPlatformConfig = backendStdenv.hostPlatform.config;
      backendStdenvCCFullPath = "${backendStdenv.cc}/bin/${backendStdenv.cc.targetPrefix}c++";
      backendStdenvCCUnwrappedCCRoot = backendStdenv.cc.cc.outPath;
      backendStdenvCCUnwrappedCCLibRoot = backendStdenv.cc.cc.lib.outPath;

      stdenvCCVersion = stdenv.cc.version;
      stdenvCCHostPlatformConfig = stdenv.hostPlatform.config;
      stdenvCCFullPath = "${stdenv.cc}/bin/${stdenv.cc.targetPrefix}c++";
      stdenvCCUnwrappedCCRoot = stdenv.cc.cc.outPath;
      stdenvCCUnwrappedCCLibRoot = stdenv.cc.cc.lib.outPath;

      # TODO: Setting cudaArchs means that we have to recompile a large number of packages because `cuda_nvcc`
      # propagates this hook, and so the input derivations change.
      # This wouldn't be an issue if we had content addressed derivations.
      # cudaArchs = cmakeCudaArchitecturesString;
    };

    passthru = {
      inherit (finalAttrs) substitutions;
      brokenAssertions = [
        {
          message = "nvccHook (currently) only supports GCC for backendStdenv host compiler";
          assertion = backendStdenv.cc.isGNU;
        }
        {
          message = "nvccHook (currently) only supports GCC for stdenv host compiler";
          assertion = stdenv.cc.isGNU;
        }
      ];
      tests = {
        dontCompressCudaFatbin = callPackages ./tests/dontCompressCudaFatbin.nix { };
        # TODO(@connorbaker): Rewrite tests.
        # nvccRunpathFixup = callPackages ./tests/nvccRunpathFixup.nix { };
      };
    };

    meta = {
      description = "Setup hook which prevents leaking NVCC host compiler libs into binaries";
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      broken = _mkMetaBroken (!(config.inHydra or false)) finalAttrs;
      maintainers = lib.teams.cuda.members;
    };
  };
in
# TODO: Document breaking change of move from cudaDontCompressFatbin to dontCompressCudaFatbin.
makeSetupHook finalAttrs ./nvccHook.bash
