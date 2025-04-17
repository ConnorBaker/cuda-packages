final: _:
let
  # Version of the default CUDA package set.
  # NOTE: This must be set manually to avoid infinite recursion.
  defaultCudaMajorMinorPatchVersion = "12.6.3";

  cudaPackagesRoot = ../development/cuda-modules;

  dontRecurseForDerivationsOrEvaluate =
    attrs:
    attrs
    // {
      # Don't recurse for derivations
      recurseForDerivations = false;
      # Don't attempt eval
      __attrsFailEvaluation = true;
    };

  fixups = import "${cudaPackagesRoot}/fixups" { inherit (final) cudaLib lib; };

  # TODO: Is it possible to use eval-time fetchers to retrieve the manifests and import them?
  # How does flake-compat get away with doing that without it being considered IFD?

  mkManifests =
    cudaMajorMinorPatchVersion:
    final.lib.mapAttrs
      (
        name: version:
        final.lib.importJSON "${cudaPackagesRoot}/manifests/${name}/redistrib_${version}.json"
      )
      {
        cublasmp = "0.4.0";
        cuda = cudaMajorMinorPatchVersion;
        cudnn = "9.8.0";
        cudss = "0.5.0";
        cuquantum = "25.03.0";
        cusolvermp = "0.6.0";
        cusparselt =
          if final.lib.versionOlder cudaMajorMinorPatchVersion "12.8.0" then "0.6.3" else "0.7.1";
        cutensor = "2.2.0";
        nppplus = "0.9.0";
        nvcomp = "4.2.0.11";
        nvjpeg2000 = "0.8.1";
        nvpl = "25.1.1";
        nvtiff = "0.5.0";
        tensorrt = if final.cudaConfig.hasJetsonCudaCapability then "10.7.0" else "10.9.0";
      };
in
{
  cudaLib = import "${cudaPackagesRoot}/lib" { inherit (final) lib; };

  # For inspecting the results of the module system evaluation.
  cudaConfig =
    let
      mkFailedAssertionsString = final.lib.foldl' (
        failedAssertionsString:
        { assertion, message, ... }:
        failedAssertionsString + final.lib.optionalString (!assertion) ("\n- " + message)
      ) "";
      failedAssertionsString = mkFailedAssertionsString cudaConfig.assertions;

      mkWarningsString = final.lib.foldl' (warningsString: warning: warningsString + "\n- " + warning) "";
      warningsString = mkWarningsString cudaConfig.warnings;

      cudaConfig =
        (final.lib.evalModules {
          modules = [ "${cudaPackagesRoot}/modules" ];
          specialArgs = {
            inherit (final) cudaLib;
            inherit defaultCudaMajorMinorPatchVersion;
            cudaCapabilities = final.config.cudaCapabilities or [ ];
            cudaForwardCompat = final.config.cudaForwardCompat or true;
            hostNixSystem = final.stdenv.hostPlatform.system;
          };
        }).config;
    in
    if failedAssertionsString != "" then
      throw "\nFailed assertions when evaluating CUDA configuration for default version ${defaultCudaMajorMinorPatchVersion}:${failedAssertionsString}"
    else if warningsString != "" then
      final.lib.warn "\nWarnings when constructing CUDA configuration for default version ${defaultCudaMajorMinorPatchVersion}:${warningsString}" cudaConfig
    else
      cudaConfig;

  # For adding packages in an ad-hoc manner.
  cudaPackagesExtensions = [ ];

  # CUDA package sets specify manifests and fixups.
  cudaPackages_12_2 = final.callPackage cudaPackagesRoot {
    inherit fixups;
    manifests = mkManifests "12.2.2";
  };

  cudaPackages_12_6 = final.callPackage cudaPackagesRoot {
    inherit fixups;
    manifests = mkManifests "12.6.3";
  };

  cudaPackages_12_8 = final.callPackage cudaPackagesRoot {
    inherit fixups;
    manifests = mkManifests "12.8.1";
  };

  # Package set aliases with a major component refer to an alias with a major and minor component in final.
  cudaPackages_12 =
    final.${final.cudaLib.utils.mkCudaPackagesVersionedName (final.lib.versions.majorMinor final.cudaConfig.defaultCudaMajorMinorPatchVersion)};

  # Unversioned package set alias refers to an alias with a major component in final.
  cudaPackages = final.cudaPackages_12;

  # Nixpkgs package sets matrixed by real architecture (e.g., `sm_90a`).
  # TODO(@connorbaker): Yes, it is computationally expensive to call nixpkgsFun.
  # No, I can't think of a different way to force re-evaluation of the fixed point -- the problem being that
  # pkgs.config is not part of the fixed point.
  pkgsCuda =
    let
      mkPkgs =
        cudaCapabilityInfo:
        final.extend (
          _: prev: {
            config = prev.config // {
              cudaCapabilities = [ cudaCapabilityInfo.cudaCapability ];
            };
          }
        );
    in
    dontRecurseForDerivationsOrEvaluate (
      final.cudaLib.utils.bimap final.cudaLib.utils.mkRealArchitecture mkPkgs
        final.cudaConfig.data.cudaCapabilityToInfo
    );
}
