final: prev:
let
  lib = import ./lib { inherit (prev) lib; };
  cudaConfig =
    (evalModules {
      modules = [
        ./modules
        {
          cudaCapabilities = final.config.cudaCapabilities or [ ];
          cudaForwardCompat = final.config.cudaForwardCompat or true;
          hostNixSystem = final.stdenv.hostPlatform.system;
        }
      ] ++ final.cudaModules;
    }).config;

  inherit (builtins) throw;
  inherit (lib.attrsets)
    attrNames
    dontRecurseIntoAttrs
    mapAttrsToList
    mergeAttrsList
    recurseIntoAttrs
    ;
  inherit (lib.cuda.utils)
    bimap
    dropDots
    mkCudaPackagesOverrideAttrsDefaultsFn
    mkCudaPackagesScope
    mkCudaPackagesVersionedName
    mkRealArchitecture
    packagesFromDirectoryRecursive'
    ;
  inherit (lib.customisation) callPackagesWith;
  inherit (lib.fixedPoints) composeManyExtensions extends;
  inherit (lib.lists) map;
  inherit (lib.modules) evalModules;
  inherit (lib.strings) versionAtLeast versionOlder;
  inherit (lib.trivial) mapNullable pipe;
  inherit (lib.upstreamable.trivial) addNameToFetchFromGitLikeArgs;
  inherit (lib.versions) major majorMinor;

  packageSetBuilder =
    cudaPackagesConfig:
    let
      # Versions
      cudaMajorMinorPatchVersion = cudaPackagesConfig.redists.cuda;
      cudaMajorMinorVersion = majorMinor cudaMajorMinorPatchVersion;
      cudaMajorVersion = major cudaMajorMinorPatchVersion;

      cudaAtLeast = versionAtLeast cudaMajorMinorPatchVersion;
      cudaOlder = versionOlder cudaMajorMinorPatchVersion;

      cudaNamePrefix = "cuda${cudaMajorMinorVersion}";

      # cudaPackages_x_y_z
      cudaPackagesMajorMinorPatchVerionName = mkCudaPackagesVersionedName cudaMajorMinorPatchVersion;
      # cudaPackages_x_y
      cudaPackagesMajorMinorVersionName = mkCudaPackagesVersionedName cudaMajorMinorVersion;
      # cudaPackages_x
      cudaPackagesMajorVersionName = mkCudaPackagesVersionedName cudaMajorVersion;

      # NOTE: To avoid callPackage-provided arguments of our package set bringing in CUDA packages from different
      # versions of the package set (this happens, for example, with MPI and UCX), our `callPackage` and
      # `callPackages` functions are built using a variant of `final` where the CUDA package set we are constructing
      # is the *default* CUDA package set at the top-level.
      # This saves us from the need to do a (potentially deep) override of any `callPackage` provided arguments to
      # ensure we are not introducing dependencies on CUDA packages from different versions of the package set.
      pkgs = final.extend (
        final: _: {
          # Don't recurse for derivations
          recurseForDerivations = false;
          # Don't attempt eval
          __attrsFailEvaluation = true;

          # cudaPackages_x_y = cudaPackages_x_y_z
          ${cudaPackagesMajorMinorVersionName} =
            final.cudaPackagesVersions.${cudaPackagesMajorMinorPatchVerionName};
          # cudaPackages_x = cudaPackages_x_y
          ${cudaPackagesMajorVersionName} = final.${cudaPackagesMajorMinorVersionName};
          # cudaPackages = cudaPackages_x
          cudaPackages = final.${cudaPackagesMajorVersionName};
        }
      );

      # TODO: All of these except newScope and cudaPackagesExtensions are invariant with respect to the default CUDA
      # packages version.
      # Ideally, they would be supplied by `final` to avoid re-evaluation of the fixed point if other args aren't
      # needed. However, there doesn't seem to be a granular way to do that at the moment.
      # cudaPackagesExtensions should come from `final` instead of `pkgs` because it is written with respect to
      # the upper-most fixed point, not the fixed point created inside each package set.
      inherit (final) cudaPackagesExtensions;
      inherit (pkgs)
        fetchFromGitHub
        fetchFromGitLab
        stdenv
        fetchzip
        newScope
        ;

      overrideAttrsDefaultsFn = mkCudaPackagesOverrideAttrsDefaultsFn {
        inherit (pkgs)
          deduplicateRunpathEntriesHook
          nixLogWithLevelAndFunctionNameHook
          noBrokenSymlinksHook
          ;
        inherit cudaNamePrefix;
      };

      cudaPackagesFun =
        # NOTE: DO NOT USE FINAL WITHIN THIS SCOPE.
        finalCudaPackages:
        mergeAttrsList (
          [
            # Core attributes which largely don't depend on packages
            (recurseIntoAttrs {
              callPackages = callPackagesWith (pkgs // finalCudaPackages);

              inherit pkgs;

              cudaPackages = dontRecurseIntoAttrs finalCudaPackages // {
                __attrsFailEvaluation = true;
              };

              # Introspection
              cudaPackagesConfig = dontRecurseIntoAttrs cudaPackagesConfig // {
                __attrsFailEvaluation = true;
              };

              # Name prefix
              inherit cudaNamePrefix;

              # CUDA versions
              inherit cudaMajorMinorPatchVersion cudaMajorMinorVersion cudaMajorVersion;

              # CUDA version comparison utilities
              inherit cudaAtLeast cudaOlder;

              # Utility function for automatically naming fetchFromGitHub derivations with `name`.
              fetchFromGitHub = args: fetchFromGitHub (addNameToFetchFromGitLikeArgs fetchFromGitHub args);
              fetchFromGitLab = args: fetchFromGitLab (addNameToFetchFromGitLikeArgs fetchFromGitLab args);

              # Aliases
              # TODO(@connorbaker): Warnings disabled for now.
              backendStdenv = stdenv;
              cudaVersion = cudaMajorMinorVersion;
              flags = finalCudaPackages.flags // {
                cudaComputeCapabilityToName = finalCudaPackages.flags.cudaCapabilityToName;
                dropDot = dropDots;
                # cudaComputeCapabilityToName = warn "cudaPackages.flags.cudaComputeCapabilityToName is deprecated, use cudaPackages.flags.cudaCapabilityToName instead" cudaCapabilityToName;
                # dropDot = warn "cudaPackages.flags.dropDot is deprecated, use lib.cuda.utils.dropDots instead" dropDots;
              };
              cudaFlags = finalCudaPackages.flags;
              # backendStdenv = warn "cudaPackages.backendStdenv has been removed, use stdenv instead" final.stdenv;
              # cudaVersion = warn "cudaPackages.cudaVersion is deprecated, use cudaPackages.cudaMajorMinorVersion instead" cudaMajorMinorVersion;
              # cudaFlags = warn "cudaPackages.cudaFlags is deprecated, use cudaPackages.flags instead" finalCudaPackages.flags;
              cudnn_8_9 = throw "cudaPackages.cudnn_8_9 has been removed, use cudaPackages.cudnn instead";
            })
          ]
          # Redistributable packages
          ++ mapAttrsToList (
            let
              inherit (finalCudaPackages) callPackage redist-builder;
              mkRedistPackage =
                callPackageOverrider: redistBuilderArgs:
                pipe redistBuilderArgs [
                  # Build the package
                  redist-builder
                  # Apply our defaults
                  (pkg: pkg.overrideAttrs overrideAttrsDefaultsFn)
                  # Apply optional fixups
                  (
                    pkg:
                    if callPackageOverrider == null then
                      pkg
                    else
                      pkg.overrideAttrs (callPackage callPackageOverrider { })
                  )
                ];
            in
            packageName:
            {
              callPackageOverrider,
              packageInfo,
              redistName,
              releaseInfo,
              srcArgs,
              supportedNixPlatformAttrs,
              supportedRedistArchAttrs,
            }:
            {
              ${packageName} = mkRedistPackage callPackageOverrider {
                inherit
                  packageInfo
                  packageName
                  redistName
                  releaseInfo
                  ;
                src = mapNullable fetchzip srcArgs;
                # NOTE: Don't need to worry about sorting the attribute names because Nix already does that.
                supportedNixPlatforms = attrNames supportedNixPlatformAttrs;
                supportedRedistArches = attrNames supportedRedistArchAttrs;
              };
            }
          ) cudaPackagesConfig.packageConfigs
          # CUDA version-specific packages
          ++ map (packagesFromDirectoryRecursive' finalCudaPackages.callPackage) cudaPackagesConfig.packagesDirectories
        );
    in
    mkCudaPackagesScope newScope (
      # User additions are included through cudaPackagesExtensions
      extends (composeManyExtensions cudaPackagesExtensions) cudaPackagesFun
    );
in
# General configuration
{
  inherit lib;

  # For inspecting the results of the module system evaluation.
  cudaConfig = dontRecurseIntoAttrs cudaConfig // {
    __attrsFailEvaluation = true;
  };

  # For changing the manifests available.
  cudaModules = [ ];

  # For adding packages in an ad-hoc manner.
  cudaPackagesExtensions = [ ];

  # Versioned package sets
  cudaPackagesVersions = bimap mkCudaPackagesVersionedName packageSetBuilder cudaConfig.cudaPackages;

  # Package set aliases with a major and minor component are drawn directly from final.cudaPackagesVersions.
  cudaPackages_12_2 = final.cudaPackagesVersions.cudaPackages_12_2_2;
  cudaPackages_12_6 = final.cudaPackagesVersions.cudaPackages_12_6_3;
  # Package set aliases with a major component refer to an alias with a major and minor component in final.
  cudaPackages_12 = final.cudaPackages_12_6;
  # Unversioned package set alias refers to an alias with a major component in final.
  cudaPackages = final.cudaPackages_12;

  # Nixpkgs package sets matrixed by real architecture (e.g., `sm_90a`).
  # TODO(@connorbaker): Yes, it is computationally expensive to call final.extend.
  # No, I can't think of a different way to force re-evaluation of the fixed point -- the problem being that
  # pkgs.config is not part of the fixed point.
  pkgsCuda = bimap mkRealArchitecture (
    gpuInfo:
    final.extend (
      _: prev: {
        # Don't recurse for derivations
        recurseForDerivations = false;
        # Don't attempt eval
        __attrsFailEvaluation = true;
        # Re-evaluate config
        config = prev.config // {
          cudaCapabilities = [ gpuInfo.cudaCapability ];
        };
      }
    )
  ) cudaConfig.data.gpus;

  # Python packages extensions
  pythonPackagesExtensions = prev.pythonPackagesExtensions or [ ] ++ [
    (
      finalPythonPackages: _:
      packagesFromDirectoryRecursive' finalPythonPackages.callPackage ./python-packages
    )
  ];
}
# Upstreamable packages
// packagesFromDirectoryRecursive' final.callPackage ./packages
# Package fixes
// {
  openmpi = prev.openmpi.override {
    # The configure flag openmpi takes expects cuda_cudart to be joined.
    cudaPackages = final.cudaPackages // {
      cuda_cudart = final.symlinkJoin {
        name = "cuda_cudart_joined";
        paths = map (
          output: final.cudaPackages.cuda_cudart.${output}
        ) final.cudaPackages.cuda_cudart.outputs;
      };
    };
  };
  # https://github.com/NixOS/nixpkgs/blob/6c4e0724e0a785a20679b1bca3a46bfce60f05b6/pkgs/by-name/uc/ucc/package.nix#L36-L39
  ucc = prev.ucc.overrideAttrs { strictDeps = false; };
}
