# NOTE: redist-builder should never take manifests or fixups as callPackage-provided arguments,
# since we want to provide the flexibility to call it directly with a different fixup or manifest.
{
  callPackage,
  cudaLib,
  cudaMajorVersion,
  cudaStdenv,
  fetchurl,
  lib,
  srcOnly,
  stdenv,
  stdenvNoCC,
}:
let
  inherit (cudaStdenv) hostRedistSystem;
  inherit (cudaLib.utils) getNixSystems mkCudaVariant mkRedistUrl;
  inherit (lib.attrsets)
    foldlAttrs
    hasAttr
    isAttrs
    attrNames
    optionalAttrs
    ;
  inherit (lib.fixedPoints) composeManyExtensions toExtension;
  inherit (lib.lists)
    naturalSort
    concatMap
    unique
    ;
  inherit (lib.trivial) mapNullable pipe;

  mkOverrideAttrsArg = fixupFn: toExtension (callPackage fixupFn { });
  genericOverrideAttrsArg = mkOverrideAttrsArg ./fixup.nix;

  getSupportedReleases =
    let
      desiredCudaVariant = mkCudaVariant cudaMajorVersion;
    in
    release:
    # Always show preference to the "source", then "linux-all" redistSystem if they are available, as they are
    # the most general.
    if release ? source then
      {
        inherit (release) source;
      }
    else if release ? linux-all then
      {
        inherit (release) linux-all;
      }
    else
      let
        hasCudaVariants = release ? cuda_variant;
      in
      foldlAttrs (
        acc: name: value:
        acc
        # If the value is an attribute, and when hasCudaVariants is true it has the relevant CUDA variant,
        # then add it to the set.
        // optionalAttrs (isAttrs value && (hasCudaVariants -> hasAttr desiredCudaVariant value)) {
          ${name} = value.${desiredCudaVariant} or value;
        }
      ) { } release;
in
# Builder-specific arguments
{
  redistName,
  packageName,
  release,
  # `fixupFn` is a `callPackage`-able arugment which is `callPackage`-ed and provided to the derivation's `overrideAttrs`.
  # It is responsible for setting up `passthru.redistBuilderArg.outputs`, among other things.
  fixupFn,
}:
let
  supportedReleases = getSupportedReleases release;

  supportedNixSystems = pipe supportedReleases [
    attrNames
    (concatMap getNixSystems)
    naturalSort
    unique
  ];

  supportedRedistSystems = naturalSort (attrNames supportedReleases);

  releaseSource =
    mapNullable
      (
        { relative_path, sha256, ... }:
        srcOnly {
          __structuredAttrs = true;
          strictDeps = true;
          stdenv = stdenvNoCC;
          pname = packageName;
          inherit (release) version;
          src = fetchurl {
            url = mkRedistUrl redistName relative_path;
            inherit sha256;
          };
        }
      )
      (
        supportedReleases.source or supportedReleases.linux-all or supportedReleases.${hostRedistSystem}
          or null
      );

  extension = composeManyExtensions [
    genericOverrideAttrsArg
    (_: prevAttrs: {
      # NOTE: We cannot use recursiveUpdate here because it will evaluate the left-hand-side to see if
      # it is an attribute set and should do recursive merging -- that will cause the builtins.throw
      # we set as defaults to be forced.
      passthru = prevAttrs.passthru or { } // {
        redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
          inherit redistName;

          # The full package name, for use in meta.description
          # e.g., "CXX Core Compute Libraries"
          releaseName = release.name;

          # The package version
          # e.g., "12.2.140"
          releaseVersion = release.version;

          # The path to the license, or null
          # e.g., "cuda_cccl/LICENSE.txt"
          licensePath = release.license_path or null;

          # The short name of the package
          # e.g., "cuda_cccl"
          inherit packageName;

          # Package source, or null
          inherit releaseSource;

          # TODO(@connorbaker): Document these
          inherit supportedRedistSystems;
          inherit supportedNixSystems;
        };
      };
    })
    (mkOverrideAttrsArg fixupFn)
  ];
in
# Last step before returning control to `callPackage` (adds the `.override` method)
# we'll apply (`overrideAttrs`) necessary package-specific "fixup" functions.
# Order is significant.
stdenv.mkDerivation (finalAttrs: extension finalAttrs { })
