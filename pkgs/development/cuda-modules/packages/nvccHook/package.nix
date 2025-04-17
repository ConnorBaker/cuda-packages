{
  arrayUtilities,
  autoFixElfFiles,
  callPackages,
  config,
  cudaLib,
  cudaNamePrefix,
  cudaStdenv,
  lib,
  makeSetupHook,
  patchelf,
  stdenv,
}:
let
  inherit (cudaLib.utils) mkFailedAssertionsString;
  inherit (cudaStdenv) nvccHostCCMatchesStdenvCC;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.trivial) warnIf warnIfNot;

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
    # path from cudaStdenv's host compiler. Generalize this to Clang as well!
    substitutions =
      {
        inherit nvccHostCCMatchesStdenvCC;
      }
      // optionalAttrs (!nvccHostCCMatchesStdenvCC) {
        cudaStdenvCCVersion = cudaStdenv.cc.version;
        cudaStdenvCCHostPlatformConfig = cudaStdenv.hostPlatform.config;
        cudaStdenvCCFullPath = "${cudaStdenv.cc}/bin/${cudaStdenv.cc.targetPrefix}c++";
        cudaStdenvCCUnwrappedCCRoot = cudaStdenv.cc.cc.outPath;
        cudaStdenvCCUnwrappedCCLibRoot = cudaStdenv.cc.cc.lib.outPath;

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
          message = "nvccHook (currently) only supports GCC for cudaStdenv host compiler";
          assertion = cudaStdenv.cc.isGNU;
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
      broken =
        let
          failedAssertionsString = mkFailedAssertionsString finalAttrs.passthru.brokenAssertions;
          hasFailedAssertions = failedAssertionsString != "";
        in
        warnIfNot config.cudaSupport
          "CUDA support is disabled and you are building a CUDA package (${finalAttrs.name}); expect breakage!"
          (
            warnIf hasFailedAssertions
              "Package ${finalAttrs.name} is marked broken due to the following failed assertions:${failedAssertionsString}"
              hasFailedAssertions
          );
      maintainers = lib.teams.cuda.members;
    };
  };
in
# TODO: Document breaking change of move from cudaDontCompressFatbin to dontCompressCudaFatbin.
makeSetupHook finalAttrs ./nvccHook.bash
