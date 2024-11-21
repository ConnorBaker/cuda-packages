final: prev:
let
  inherit (final) lib cudaConfig;
  inherit (lib.modules) evalModules;

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

  hasJetsonTarget =
    (getJetsonTargets cudaConfig.data.gpus (final.config.cudaCapabilities or [ ])) != [ ];

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

          # CUDA versions
          inherit cudaMajorMinorPatchVersion cudaMajorMinorVersion cudaMajorVersion;

          # CUDA version comparison utilities
          inherit
            cudaAtLeast
            cudaAtMost
            cudaBoundedExclusive
            cudaBoundedInclusive
            cudaNewer
            cudaOlder
            isCuda11
            isCuda12
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
            cudaVersion = warn "cudaPackages.cudaVersion is deprecated, use cudaPackages.cudaMajorMinorVersion instead" cudaMajorMinorVersion;
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
            ) { } cudaConfig.redists
          )
          # Common packages
          (
            finalCudaPackages: _:
            packagesFromDirectoryRecursive {
              inherit (finalCudaPackages) callPackage;
              directory = ./cuda-packages/common;
            }
          )
        ]
        # CUDA 11-specific packages
        ++ optionals (isCuda11 && cudaConfig.cuda11.packagesDirectory != null) [
          (
            finalCudaPackages: _:
            packagesFromDirectoryRecursive {
              inherit (finalCudaPackages) callPackage;
              directory = cudaConfig.cuda11.packagesDirectory;
            }
          )
        ]
        # CUDA 12-specific packages
        ++ optionals (isCuda12 && cudaConfig.cuda12.packagesDirectory != null) [
          (
            finalCudaPackages: _:
            packagesFromDirectoryRecursive {
              inherit (finalCudaPackages) callPackage;
              directory = cudaConfig.cuda12.packagesDirectory;
            }
          )
        ]
        # User additions
        ++ final.cudaPackagesExtensions;
    in
    makeScope final.newScope (extends (composeManyExtensions extensions) cudaPackagesFun);
in
{
  # Add our attribute sets to lib.
  # TODO: Can't use final.lib here because we get infinite recursion.
  # This means that we clobber any changes to lib made by the user after this overlay is applied.
  lib = import ./lib { inherit (prev) lib; };

  # For inspecting the results of the module system evaluation.
  cudaConfig =
    (evalModules {
      modules = [ ./modules ] ++ final.cudaModules;
    }).config;

  # For changing the manifests available.
  cudaModules = [ ];

  # For adding packages in an ad-hoc manner.
  cudaPackagesExtensions = [ ];

  # Our package sets, configured for the compute capabilities in config.
  cudaPackages_11 = warn "cudaPackages_11 is EOL and marked for removal" prev.cudaPackages_11;
  cudaPackages_12 = packageSetBuilder cudaConfig.cuda12.majorMinorPatchVersion;
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
    ) (dontRecurseIntoAttrs { }) cudaConfig.data.gpus;

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
