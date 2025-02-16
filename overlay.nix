final: prev:
let
  inherit (builtins) throw;
  inherit (cudaLib.utils)
    addNameToFetchFromGitLikeArgs
    bimap
    dropDots
    mkCudaPackagesOverrideAttrsDefaultsFn
    mkCudaPackagesScope
    mkCudaPackagesVersionedName
    mkRealArchitecture
    packagesFromDirectoryRecursive'
    ;
  inherit (lib.attrsets)
    attrNames
    mapAttrsToList
    mergeAttrsList
    recurseIntoAttrs
    ;
  inherit (lib.customisation) callPackagesWith;
  inherit (lib.fixedPoints) composeManyExtensions extends;
  inherit (lib.lists) map;
  inherit (lib.modules) evalModules;
  inherit (lib.strings) versionAtLeast versionOlder;
  inherit (lib.trivial) mapNullable pipe;
  inherit (lib.versions) major majorMinor;
  inherit (prev) lib;

  # We need access to cudaLib constructed with `prev` to avoid falling into the infinite recursion tarpit.
  cudaLib = import ./cuda-lib { inherit lib; };

  dontRecurseForDerivationsOrEvaluate =
    attrs:
    attrs
    // {
      # Don't recurse for derivations
      recurseForDerivations = false;
      # Don't attempt eval
      __attrsFailEvaluation = true;
    };

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
      # NOTE: We only re-evaluate the fixed point when the three CUDA package set aliases don't match the default CUDA
      # package set.
      pkgs =
        if
          final.${cudaPackagesMajorMinorVersionName}.cudaMajorMinorPatchVersion == cudaMajorMinorPatchVersion
          && final.${cudaPackagesMajorVersionName}.cudaMajorMinorPatchVersion == cudaMajorMinorPatchVersion
          && final.cudaPackages.cudaMajorMinorPatchVersion == cudaMajorMinorPatchVersion
        then
          dontRecurseForDerivationsOrEvaluate final
        else
          final.extend (
            final: _:
            dontRecurseForDerivationsOrEvaluate {
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

              cudaPackages = dontRecurseForDerivationsOrEvaluate finalCudaPackages;

              # Introspection
              cudaPackagesConfig = dontRecurseForDerivationsOrEvaluate cudaPackagesConfig;

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
                cudaComputeCapabilityToName = finalCudaPackages.flags.cudaCapabilityToArchName;
                dropDot = dropDots;
                # cudaComputeCapabilityToName = warn "cudaPackages.flags.cudaComputeCapabilityToName is deprecated, use cudaPackages.flags.cudaCapabilityToName instead" cudaCapabilityToName;
                # dropDot = warn "cudaPackages.flags.dropDot is deprecated, use cudaLibs.utils.dropDots instead" dropDots;
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
              supportedNixSystemAttrs,
              supportedRedistSystemAttrs,
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
                supportedNixSystems = attrNames supportedNixSystemAttrs;
                supportedRedistSystems = attrNames supportedRedistSystemAttrs;
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
  # Make sure to use `lib` from `prev` to avoid attribute names (in which attribute sets are strict) depending on the
  # fixed point, as this causes infinite recursion.
  cudaLib = dontRecurseForDerivationsOrEvaluate cudaLib;

  # For inspecting the results of the module system evaluation.
  cudaConfig =
    dontRecurseForDerivationsOrEvaluate
      (evalModules {
        modules = [
          ./modules
          {
            cudaCapabilities = final.config.cudaCapabilities or [ ];
            cudaForwardCompat = final.config.cudaForwardCompat or true;
            hostNixSystem = final.stdenv.hostPlatform.system;
          }
        ] ++ final.cudaModules;
        specialArgs = {
          inherit (final) cudaLib;
        };
      }).config;

  # For changing the manifests available.
  cudaModules = [ ];

  # For adding packages in an ad-hoc manner.
  cudaPackagesExtensions = [ ];

  # Versioned package sets
  cudaPackagesVersions =
    bimap mkCudaPackagesVersionedName packageSetBuilder
      final.cudaConfig.cudaPackages;

  # Package set aliases with a major and minor component are drawn directly from final.cudaPackagesVersions.
  cudaPackages_12_2 = final.cudaPackagesVersions.cudaPackages_12_2_2;
  cudaPackages_12_6 = final.cudaPackagesVersions.cudaPackages_12_6_3;
  cudaPackages_12_8 = final.cudaPackagesVersions.cudaPackages_12_8_0;
  # Package set aliases with a major component refer to an alias with a major and minor component in final.
  # TODO: Deferring upgrade to CUDA 12.8 until separate compilation works.
  cudaPackages_12 = final.cudaPackages_12_6;
  # Unversioned package set alias refers to an alias with a major component in final.
  cudaPackages = final.cudaPackages_12;

  # Nixpkgs package sets matrixed by real architecture (e.g., `sm_90a`).
  # TODO(@connorbaker): Yes, it is computationally expensive to call final.extend.
  # No, I can't think of a different way to force re-evaluation of the fixed point -- the problem being that
  # pkgs.config is not part of the fixed point.
  pkgsCuda = bimap mkRealArchitecture (
    cudaCapabilityInfo:
    final.extend (
      _: prev:
      dontRecurseForDerivationsOrEvaluate {
        # Re-evaluate config
        config = prev.config // {
          cudaCapabilities = [ cudaCapabilityInfo.cudaCapability ];
        };
      }
    )
  ) final.cudaConfig.data.cudaCapabilityToInfo;

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
