final: prev:
let
  inherit (final) lib;
  inherit (lib.modules) evalModules;
  inherit
    (evalModules {
      modules = final.cudaModules;
    })
    config
    ;

  inherit (builtins)
    match
    substring
    throw
    toJSON
    ;
  inherit (lib.cuda.utils)
    buildRedistPackages
    getJetsonTargets
    getRedistArch
    mkCudaVariant
    mkRealArchitecture
    versionAtMost
    versionBoundedExclusive
    versionBoundedInclusive
    versionNewer
    ;
  inherit (lib.attrsets)
    attrNames
    dontRecurseIntoAttrs
    foldlAttrs
    optionalAttrs
    recurseIntoAttrs
    ;
  inherit (lib.customisation) makeScope;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.fixedPoints) composeManyExtensions extends;
  inherit (lib.lists)
    foldl'
    head
    length
    optionals
    ;
  inherit (lib.strings)
    concatStringsSep
    removePrefix
    versionAtLeast
    versionOlder
    ;
  inherit (lib.trivial)
    warn
    throwIf
    ;
  inherit (lib.versions) major majorMinor;

  hasJetsonTarget = (getJetsonTargets config.data.gpus (final.config.cudaCapabilities or [ ])) != [ ];

  hostRedistArch = getRedistArch hasJetsonTarget final.stdenv.hostPlatform.system;

  addNameToFetchFromGitLikeArgs =
    args:
    if args ? name then
      # Use `name` when provided.
      args
    else
      let
        inherit (args) owner repo rev;
        revStrippedRefsTags = removePrefix "refs/tags/" rev;
        isTag = revStrippedRefsTags != rev;
        isHash = match "^[0-9a-f]{40}$" rev == [ ];
        shortHash = substring 0 8 rev;
      in
      args
      // {
        name = concatStringsSep "-" [
          owner
          repo
          (
            if isTag then
              revStrippedRefsTags
            else if isHash then
              shortHash
            else
              throw "Expected either a tag or a hash for the revision"
          )
        ];
      };

  fetchFromGitHubAutoName = args: final.fetchFromGitHub (addNameToFetchFromGitLikeArgs args);
  fetchFromGitLabAutoName = args: final.fetchFromGitLab (addNameToFetchFromGitLikeArgs args);

  packageSetBuilder =
    cudaMajorMinorPatchVersion:
    let
      # Attribute set membership can depend on the CUDA version, so we declare these here and ensure they do not rely on
      # the fixed point.
      cudaMajorMinorVersion = majorMinor cudaMajorMinorPatchVersion;
      cudaMajorVersion = major cudaMajorMinorPatchVersion;

      cudaAtLeast = versionAtLeast cudaMajorMinorPatchVersion;
      cudaAtMost = versionAtMost cudaMajorMinorPatchVersion;
      cudaNewer = versionNewer cudaMajorMinorPatchVersion;
      cudaOlder = versionOlder cudaMajorMinorPatchVersion;
      cudaBoundedExclusive = min: max: versionBoundedExclusive min max cudaMajorMinorPatchVersion;
      cudaBoundedInclusive = min: max: versionBoundedInclusive min max cudaMajorMinorPatchVersion;

      isCuda11 = cudaMajorVersion == "11";
      isCuda12 = cudaMajorVersion == "12";
      # NOTE: Remember that hostRedistArch uses NVIDIA's naming convention, and that the Jetson is linux-aarch64.
      # ARM servers are linux-sbsa.
      isJetsonBuild = hostRedistArch == "linux-aarch64";

      # Packaging-specific utilities.
      desiredCudaVariant = mkCudaVariant cudaMajorMinorPatchVersion;

      cudaPackagesFun =
        finalCudaPackages:
        recurseIntoAttrs {
          cudaPackages = dontRecurseIntoAttrs finalCudaPackages // {
            __attrsFailEvaluation = true;
          };

          pkgs = dontRecurseIntoAttrs final // {
            __attrsFailEvaluation = true;
          };

          config = dontRecurseIntoAttrs config // {
            __attrsFailEvaluation = true;
          };

          # CUDA versions
          inherit cudaMajorMinorPatchVersion cudaMajorMinorVersion cudaMajorVersion;
          cudaVersion = warn "cudaPackages.cudaVersion is deprecated, use cudaPackages.cudaMajorMinorVersion instead" cudaMajorMinorVersion;

          # CUDA version comparison utilities
          inherit
            cudaAtLeast
            cudaAtMost
            cudaBoundedExclusive
            cudaBoundedInclusive
            cudaNewer
            cudaOlder
            ;

          # Utility function for automatically naming fetchFromGitHub derivations with `name`.
          fetchFromGitHub = fetchFromGitHubAutoName;
          fetchFromGitLab = fetchFromGitLabAutoName;

          # Ensure protobuf is fixed to a specific version which is broadly compatible.
          # TODO: Make conditional on not being cudaPackages_11-jetson, which supports older versions of software and
          # will require an older protobuf.
          # NOTE: This is currently blocked on onnxruntime:
          # https://github.com/microsoft/onnxruntime/issues/21308
          protobuf = final.protobuf_25;
        };

      extensions =
        [
          # Aliases
          (finalCudaPackages: _: {
            cudaFlags = warn "cudaPackages.cudaFlags is deprecated, use cudaPackages.flags instead" finalCudaPackages.flags;
            cudnn_8_9 = throw "cudaPackages.cudnn_8_9 has been removed, use cudaPackages.cudnn instead";
          })
          # Redistributable packages
          (
            finalCudaPackages: _:
            foldlAttrs (
              acc: redistName: redistConfig:
              let
                manifestVersions =
                  if redistName == "cuda" then
                    [ cudaMajorMinorPatchVersion ]
                  else
                    attrNames redistConfig.versionedManifests;
                manifestVersion = head manifestVersions;
              in
              # TODO: This will prevent users adding their own redists.
              throwIf (
                length manifestVersions != 1
              ) "Expected exactly one version for ${redistName} manifests (found ${toJSON manifestVersions})" acc
              // buildRedistPackages {
                inherit
                  desiredCudaVariant
                  finalCudaPackages
                  hostRedistArch
                  manifestVersion
                  redistConfig
                  redistName
                  ;
              }
            ) { } config.redists
          )
          # cudaPackagesCommon
          (
            finalCudaPackages: _:
            packagesFromDirectoryRecursive {
              inherit (finalCudaPackages) callPackage;
              directory = ./cuda-packages/common;
            }
          )
        ]
        # cudaPackages_11
        ++ optionals isCuda11 [
          (
            finalCudaPackages: _:
            packagesFromDirectoryRecursive {
              inherit (finalCudaPackages) callPackage;
              directory = ./cuda-packages/11;
            }
          )

        ]
        # cudaPackages_11-jetson
        ++ optionals (isCuda11 && isJetsonBuild) [
          (
            finalCudaPackages: _:
            packagesFromDirectoryRecursive {
              inherit (finalCudaPackages) callPackage;
              directory = ./cuda-packages/11-jetson;
            }
          )

        ]
        # cudaPackages_12
        ++ optionals isCuda12 [
          (
            finalCudaPackages: _:
            packagesFromDirectoryRecursive {
              inherit (finalCudaPackages) callPackage;
              directory = ./cuda-packages/12;
            }
          )
        ]
        ++ final.cudaPackagesExtensions;
    in
    makeScope final.newScope (extends (composeManyExtensions extensions) cudaPackagesFun);
in
{
  # Add our attribute sets to lib.
  # TODO: Can't use final.lib here because we get infinite recursion.
  # This means that we clobber any changes to lib made by the user after this overlay is applied.
  lib = import ./lib { inherit (prev) lib; };

  # For changing the manifests available.
  cudaModules = [ ./modules ];

  # For adding packages in an ad-hoc manner.
  cudaPackagesExtensions = [ ];

  # Our package sets, configured for the compute capabilities in config.
  cudaPackages_11 = packageSetBuilder config.cuda11.majorMinorPatchVersion;
  cudaPackages_12 = packageSetBuilder config.cuda12.majorMinorPatchVersion;
  cudaPackages = final.cudaPackages_12;

  # Nixpkgs package sets matrixed by real architecture (e.g., `sm_90a`).
  # TODO(@connorbaker): Only keeps GPUs which are supported by the current CUDA version.
  pkgsCuda =
    let
      inherit (final.cudaPackages) cudaAtLeast cudaAtMost;
      isAarch64Linux = final.stdenv.hostPlatform.system == "aarch64-linux";
    in
    foldl' (
      acc:
      {
        computeCapability,
        isJetson,
        # TODO: Use versioned names (i.e., minCudaMajorMinorVersion)
        minCudaVersion,
        maxCudaVersion,
        ...
      }:
      acc
      //
        optionalAttrs
          (
            # Lower bound must be satisfied
            cudaAtLeast minCudaVersion
            # Upper bound must be empty or satisfied
            && (maxCudaVersion == null || cudaAtMost maxCudaVersion)
            # Jetson targets are only included when final.stdenv.hostPlatform.system is aarch64-linux
            && (isJetson -> isAarch64Linux)
          )
          {
            # TODO(@connorbaker): Yes, this is computationally expensive.
            # No, I can't think of a different way to force re-evaluation of the fixed point.
            ${mkRealArchitecture computeCapability} = final.extend (
              _: prev':
              dontRecurseIntoAttrs {
                __attrsFailEvaluation = true;
                config = prev'.config // {
                  cudaCapabilities = [ computeCapability ];
                };
              }
            );
          }
    ) (dontRecurseIntoAttrs { }) config.data.gpus;

  # Package fixes
  openmpi = prev.openmpi.override (prevAttrs: {
    # The configure flag openmpi takes expects cuda_cudart to be joined.
    cudaPackages = prevAttrs.cudaPackages // {
      cuda_cudart = final.symlinkJoin {
        name = "cuda_cudart_joined";
        paths = map (
          output: prevAttrs.cudaPackages.cuda_cudart.${output}
        ) prevAttrs.cudaPackages.cuda_cudart.outputs;
      };
    };
  });
}
