final: _:
let
  dontRecurseForDerivationsOrEvaluate =
    attrs:
    attrs
    // {
      # Don't recurse for derivations
      recurseForDerivations = false;
      # Don't attempt eval
      __attrsFailEvaluation = true;
    };

  # NOTE: We avoid path interpolation because it would copy the cudaPackagesPath to a new store output:
  # https://nix.dev/manual/nix/2.28/language/string-interpolation#interpolated-expression
  # Instead, concatenate the path with the string.

  fixups = import (final.cudaLib.data.cudaPackagesPath + "/fixups") { inherit (final) lib; };

  # TODO: Is it possible to use eval-time fetchers to retrieve the manifests and import them?
  # How does flake-compat get away with doing that without it being considered IFD?

  # NOTE: Because manifests are used to add redistributables to the package set,
  # we cannot have values depend on the package set itself, or we run into infinite recursion.
  mkManifests =
    let
      # Since Jetson capabilities are never built by default, we can check if any of them were requested
      # through final.config.cudaCapabilities and use that to determine if we should change some manifest versions.
      # Copied from cudaStdenv.
      jetsonCudaCapabilities = final.lib.filter (
        cudaCapability: final.cudaLib.data.cudaCapabilityToInfo.${cudaCapability}.isJetson
      ) final.cudaLib.data.allSortedCudaCapabilities;
      hasJetsonCudaCapability =
        final.lib.intersectLists jetsonCudaCapabilities (final.config.cudaCapabilities or [ ]) != [ ];
      importManifest =
        name: version:
        final.lib.importJSON (
          final.cudaLib.data.cudaPackagesPath + "/manifests/${name}/redistrib_${version}.json"
        );
    in
    cudaMajorMinorPatchVersion:
    final.lib.mapAttrs importManifest {
      cublasmp = "0.4.0";
      cuda = cudaMajorMinorPatchVersion;
      cudnn = "9.8.0";
      cudss = "0.5.0";
      cuquantum = "25.03.0";
      cusolvermp = "0.6.0";
      cusparselt =
        if final.lib.versionOlder cudaMajorMinorPatchVersion "12.8.0" then "0.6.3" else "0.7.1";
      cutensor = "2.2.0";
      nppplus = "0.10.0";
      nvcomp = "4.2.0.11";
      nvjpeg2000 = "0.8.1";
      nvpl = "25.1.1";
      nvtiff = "0.5.0";
      tensorrt = if hasJetsonCudaCapability then "10.7.0" else "10.9.0";
    };
in
{
  cudaLib = import ../development/cuda-modules/lib { inherit (final) lib; };

  # For adding packages in an ad-hoc manner.
  cudaPackagesExtensions = [ ];

  # CUDA package sets specify manifests and fixups.
  cudaPackages_12_2 = final.callPackage final.cudaLib.data.cudaPackagesPath {
    inherit fixups;
    manifests = mkManifests "12.2.2";
  };

  cudaPackages_12_6 = final.callPackage final.cudaLib.data.cudaPackagesPath {
    inherit fixups;
    manifests = mkManifests "12.6.3";
  };

  cudaPackages_12_8 = final.callPackage final.cudaLib.data.cudaPackagesPath {
    inherit fixups;
    manifests = mkManifests "12.8.1";
  };

  cudaPackages_12_9 = final.callPackage final.cudaLib.data.cudaPackagesPath {
    inherit fixups;
    manifests = mkManifests "12.9.0";
  };

  # Package set aliases with a major component refer to an alias with a major and minor component in final.
  cudaPackages_12 = final.cudaPackages_12_6;

  # Unversioned package set alias refers to an alias with a major component in final.
  cudaPackages = final.cudaPackages_12;

  # Nixpkgs package sets matrixed by real architecture (e.g., `sm_90a`).
  # TODO(@connorbaker): Yes, it is computationally expensive to call nixpkgsFun.
  # No, I can't think of a different way to force re-evaluation of the fixed point -- the problem being that
  # pkgs.config is not part of the fixed point.
  # NOTE: Not every architecture is supported by every CUDA version!
  pkgsCuda =
    let
      mkPkgs =
        cudaCapabilityInfo:
        final.extend (
          _: prev: {
            config = prev.config // {
              cudaSupport = true;
              # Not supported by architecture-specific feature sets, so disable for all.
              # Users can choose to build for family-specific feature sets if they wish.
              cudaForwardCompat = false;
              cudaCapabilities = [ cudaCapabilityInfo.cudaCapability ];
            };
          }
        );
    in
    dontRecurseForDerivationsOrEvaluate (
      final.lib.mapAttrs' (
        name: value: final.lib.nameValuePair (final.cudaLib.utils.mkRealArchitecture name) (mkPkgs value)
      ) final.cudaLib.data.cudaCapabilityToInfo
    );
}
