# TODO(@connorbaker): Utility functions for brokenConditions/badPlatformsConditions.
{
  cuda-lib,
  lib,
  upstreamable-lib,
}:
let
  inherit (cuda-lib.data) redistUrlPrefix;
  inherit (cuda-lib.utils)
    getLibPath
    majorMinorPatch
    majorMinorPatchBuild
    mapPackageInfoRedistsToList
    mkCudaVariant
    mkRedistUrl
    mkRelativePath
    mkTensorRTUrl
    packageSatisfiesRedistRequirements
    versionPolicyToNumComponents
    versionPolicyToVersionFunction
    ;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets)
    attrNames
    attrValues
    filterAttrs
    genAttrs
    intersectAttrs
    mapAttrs
    mapAttrs'
    mapAttrsToList
    optionalAttrs
    removeAttrs
    ;
  inherit (lib.customisation) makeOverridable;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.licenses) nvidiaCudaRedist;
  inherit (lib.lists)
    findFirst
    flatten
    groupBy'
    reverseList
    ;
  inherit (lib.options) mkOption;
  inherit (lib.strings)
    concatStringsSep
    hasPrefix
    removeSuffix
    replaceStrings
    versionAtLeast
    versionOlder
    ;
  inherit (lib.trivial)
    const
    flip
    functionArgs
    id
    importJSON
    mapNullable
    pipe
    setFunctionArgs
    ;
  inherit (lib.versions) major majorMinor;
in
{
  inherit (upstreamable-lib.versions)
    dropDots
    majorMinorPatch
    majorMinorPatchBuild
    ;

  /**
    Maps `mkOption` over the values of an attribute set.

    # Type

    ```
    mkOptions :: AttrSet -> AttrSet
    ```

    # Arguments

    attrs
    : The attribute set to map over
  */
  mkOptions = mapAttrs (const mkOption);

  /**
    Function to map over the `packageInfo` elements of a `Redists`, returning a list of the results.

    The function must accept an attribute set with the following attributes:

    - cudaVariant: The CUDA variant of the package
    - packageInfo: The package information
    - packageName: The name of the package
    - redistArch: The redist architecture of the package
    - redistName: The name of the redistributable
    - releaseInfo: The release information of the package
    - version: The version of the manifest

    # Type

    ```
    mapPackageInfoRedistsToList :: ({ cudaVariant :: CudaVariant
                                    , packageInfo :: PackageInfo
                                    , packageName :: PackageName
                                    , redistArch :: RedistArch
                                    , redistName :: RedistName
                                    , releaseInfo :: ReleaseInfo
                                    , version :: Version
                                    } -> B)
                                -> Redists
                                -> List B
    ```

    # Arguments

    f
    : Function to apply

    redists
    : The `Redists` value to map over
  */
  mapPackageInfoRedistsToList =
    f: redists:
    flatten (
      mapAttrsToList (
        redistName: redistConfig:
        mapAttrsToList (
          version:
          mapAttrsToList (
            packageName:
            { releaseInfo, packages }:
            mapAttrsToList (
              redistArch:
              mapAttrsToList (
                cudaVariant: packageInfo:
                f {
                  inherit
                    cudaVariant
                    packageInfo
                    packageName
                    redistArch
                    redistName
                    releaseInfo
                    version
                    ;
                }
              )
            ) packages
          )
        ) redistConfig.versionedManifests
      ) redists
    );

  /**
    Helper function to build a `redistConfig`.

    # Type

    ```
    mkRedistConfig :: { hasOverrides :: Bool
                      , path :: Path
                      , versionPolicy :: VersionPolicy
                      }
                   -> RedistConfig
    ```

    # Arguments

    hasOverrides
    : Whether the redistributable has overrides

    path
    : The path to the redistributable directory

    versionPolicy
    : The version policy to use
  */
  mkRedistConfig =
    {
      hasOverrides,
      path,
      versionPolicy,
    }:
    {
      inherit versionPolicy;
      overrides =
        if hasOverrides then
          packagesFromDirectoryRecursive {
            # Function which loads the file as a Nix expression and ignores the second argument.
            # NOTE: We don't actually want to callPackage these functions at this point, so we use builtins.import
            # instead. We do, however, have to match the callPackage signature.
            callPackage = path: _: builtins.import path;
            directory = path + "/overrides";
          }
        else
          { };
      versionedManifests = mapAttrs' (filename: _: {
        name = removeSuffix ".json" filename;
        value = importJSON (path + "/versioned-manifests/${filename}");
      }) (builtins.readDir (path + "/versioned-manifests"));
    };

  /**
    Function to generate a URL for something in the redistributable tree.

    # Type

    ```
    mkRedistUrl :: RedistName -> NonEmptyStr -> RedistUrl
    ```

    # Arguments

    redistName
    : The name of the redistributable

    relativePath
    : The relative path to a file in the redistributable tree
  */
  mkRedistUrl =
    redistName:
    assert assertMsg (
      redistName != "tensorrt"
    ) "mkRedistUrl: tensorrt does not use standard naming conventions for URLs; use mkTensorRTUrl";
    relativePath:
    concatStringsSep "/" [
      redistUrlPrefix
      redistName
      "redist"
      relativePath
    ];

  /**
    Function to recreate a relative path for a redistributable.

    NOTE: `redistName` cannot be `"tensorrt"` as it does not use standard naming conventions for relative paths.

    # Type

    ```
    mkRelativePath :: { packageName :: PackageName
                      , redistArch :: RedistArch
                      , redistName :: RedistName
                      , releaseInfo :: ReleaseInfo
                      , cudaVariant :: CudaVariant
                      , relativePath :: NullOr NonEmptyStr
                      }
                   -> String
    ```

    # Arguments

    packageName
    : The name of the package

    redistArch
    : The redist architecture of the package

    redistName
    : The name of the redistributable

    releaseInfo
    : The release information of the package

    cudaVariant
    : The CUDA variant of the package

    relativePath
    : An optional relative path to the redistributable, defaults to null
  */
  mkRelativePath =
    {
      packageName,
      redistArch,
      redistName,
      releaseInfo,
      cudaVariant,
      relativePath ? null,
      ...
    }:
    assert assertMsg (redistName != "tensorrt")
      "mkRelativePath: tensorrt does not use standard naming conventions for relative paths; use mkTensorRTUrl";
    if relativePath != null then
      relativePath
    else
      concatStringsSep "/" [
        packageName
        redistArch
        (concatStringsSep "-" [
          packageName
          redistArch
          (releaseInfo.version + (if cudaVariant != "None" then "_${cudaVariant}" else ""))
          "archive.tar.xz"
        ])
      ];

  /**
    Function to generate a URL for TensorRT.

    # Type

    ```
    mkTensorRTUrl :: String -> String
    ```

    # Arguments

    relativePath
    : The relative path to a file in the redistributable tree
  */
  mkTensorRTUrl =
    relativePath:
    concatStringsSep "/" [
      redistUrlPrefix
      "machine-learning"
      relativePath
    ];

  # TODO: Alphabetize

  /**
    Function to build a redistributable package.

    # Type

    ```
    buildRedistPackage :: AttrSet -> FlattenedRedistsElem -> Package
    ```

    # Arguments

    final
    : The fixed-point of the package set

    flattenedRedistsElem
    : The flattened `Redists` element to build
  */
  buildRedistPackage =
    let
      redistBuilderFn = builtins.import ../redist-builder;
      redistBuilderFnArgs = functionArgs redistBuilderFn;
    in
    final:
    flattenedRedistsElem@{
      packageName,
      redistName,
      releaseInfo,
      packageInfo,
      ...
    }:
    let
      # Attribute set of functions which are callPackage-able and provide arguments for a package's overrideAttrs. The
      # attribute set is keyed by redistributable name and package name.

      # These overrides contain the package-specific logic required to build or fixup a package constructed with the
      # redistributable builder.
      overrideAttrsFnFn = final.config.redists.${redistName}.overrides.${packageName} or null;
      overrideAttrsFnFnArgs = if overrideAttrsFnFn != null then functionArgs overrideAttrsFnFn else { };

      redistBuilderArgs = {
        inherit (flattenedRedistsElem) packageInfo packageName releaseInfo;
        libPath = getLibPath final.cudaMajorMinorPatchVersion packageInfo.features.cudaVersionsInLib;
        # The source is given by the tarball, which we unpack and use as a FOD.
        src = final.pkgs.fetchzip {
          url =
            if redistName == "tensorrt" then
              mkTensorRTUrl packageInfo.relativePath
            else
              mkRedistUrl redistName (
                mkRelativePath (flattenedRedistsElem // { inherit (packageInfo) relativePath; })
              );
          hash = packageInfo.recursiveHash;
        };
      };

      # Union of all arguments provided to the redistributable builder function and the function which produces arguments
      # to provide to overrideAttrs.
      # Get the arguments from callPackage and remove the override arguments.
      allRequestedArgs = redistBuilderFnArgs // overrideAttrsFnFnArgs;
      package = pipe allRequestedArgs [
        # Create a function which returns its argument -- but make it expect all the arguments we need!
        (setFunctionArgs (pkgs: pkgs))
        # Call our newly minted function with callPackage to get all the arguments we need.
        (flip final.callPackage redistBuilderArgs)
        # Remove the callPackage-provided attributes.
        (flip removeAttrs [
          "override"
          "overrideDerivation"
        ])
        # Build the package, applying overrides if they exist, and provide a new override to handle the
        # split-overrides coming from both the redistributable builder and the overrideAttrs function.
        (makeOverridable (
          providedArgs:
          let
            # Get the arguments we'll need to provide to our mainfest builder and overrideAttrs-producing function.
            providedManifestBuilderFnArgs = intersectAttrs redistBuilderFnArgs providedArgs;
            providedOverrideAttrsFnFnArgs = intersectAttrs overrideAttrsFnFnArgs providedArgs;
            # Update the package license before applying the overrideAttrs function.
            pkg = (redistBuilderFn providedManifestBuilderFnArgs).overrideAttrs (prevAttrs: {
              meta = prevAttrs.meta // {
                license = nvidiaCudaRedist // {
                  url =
                    let
                      licensePath =
                        if releaseInfo.licensePath != null then releaseInfo.licensePath else "${packageName}/LICENSE.txt";
                    in
                    "https://developer.download.nvidia.com/compute/${redistName}/redist/${licensePath}";
                };
              };
            });
          in
          if overrideAttrsFnFn != null then
            pkg.overrideAttrs (overrideAttrsFnFn providedOverrideAttrsFnFnArgs)
          else
            pkg
        ))
      ];
    in
    package;

  /**
    Returns the path to the CUDA library directory for a given version or null if no such version exists.

    Implementation note: Find the first libPath in the list of cudaVersionsInLib that is a prefix of the current cuda
    version.

    # Example

    ```nix
    cuda-lib.utils.getLibPath "11.0" null
    => null
    ```

    ```nix
    cuda-lib.utils.getLibPath "11.0" [ "10.2" "11" "11.0" "12" ]
    => "11.0"
    ```

    # Type

    ```
    getLibPath :: Version -> NullOr (List Version) -> NullOr Version
    ```

    # Arguments

    fullCudaVersion
    : The full version of CUDA

    cudaVersionsInLib
    : Null or the list of CUDA versions in the lib directory
  */
  getLibPath =
    fullCudaVersion:
    mapNullable (
      cudaVersionsInLib:
      findFirst (flip hasPrefix (majorMinor fullCudaVersion)) null (reverseList cudaVersionsInLib)
    );

  /**
    Maps a NVIDIA redistributable architecture to Nix platforms.

    NOTE: This function returns a list of platforms because the redistributable architecture `"source"` can be
    built on multiple platforms.

    NOTE: This function *will* be called by unsupported platforms because `cudaPackages` is part of
    `all-packages.nix`, which is evaluated on all platforms. As such, we need to handle unsupported
    platforms gracefully.

    # Example

    ```nix
    cuda-lib.utils.getNixPlatforms "linux-sbsa"
    => [ "aarch64-linux" ]
    ```

    ```nix
    cuda-lib.utils.getNixPlatforms "linux-aarch64"
    => [ "aarch64-linux" ]
    ```

    # Type

    ```
    getNixPlatforms :: RedistArch -> List String
    ```

    # Arguments

    redistArch
    : The NVIDIA redistributable architecture
  */
  getNixPlatforms =
    redistArch:
    if redistArch == "linux-sbsa" then
      [ "aarch64-linux" ]
    else if redistArch == "linux-aarch64" then
      [ "aarch64-linux" ]
    else if redistArch == "linux-x86_64" then
      [ "x86_64-linux" ]
    else if redistArch == "linux-ppc64le" then
      [ "powerpc64le-linux" ]
    else if redistArch == "windows-x86_64" then
      [ "x86_64-windows" ]
    else if redistArch == "source" then
      [
        "aarch64-linux"
        "powerpc64le-linux"
        "x86_64-linux"
        "x86_64-windows"
      ]
    else
      [ "unsupported" ];

  /**
    Function to map Nix system to NVIDIA redist arch

    NOTE: We swap out the default `linux-sbsa` redist (for server-grade ARM chips) with the
    `linux-aarch64` redist (which is for Jetson devices) if we're building any Jetson devices.
    Since both are based on aarch64, we can only have one or the other, otherwise there's an
    ambiguity as to which should be used.

    NOTE: This function *will* be called by unsupported systems because `cudaPackages` is part of
    `all-packages.nix`, which is evaluated on all systems. As such, we need to handle unsupported
    systems gracefully.

    # Example

    ```nix
    cuda-lib.utils.getRedistArch true "aarch64-linux"
    => "linux-aarch64"
    ```

    ```nix
    cuda-lib.utils.getRedistArch false "aarch64-linux"
    => "linux-sbsa"
    ```

    ```nix
    cuda-lib.utils.getRedistArch false "powerpc64le-linux"
    => "linux-ppc64le"
    ```

    # Type

    ```
    getRedistArch :: Bool -> String -> String
    ```

    # Arguments

    isJetsonBuild
    : Whether the build is for a Jetson device

    nixSystem
    : The Nix system
  */
  getRedistArch =
    isJetsonBuild: nixSystem:
    if isJetsonBuild then
      if nixSystem == "aarch64-linux" then "linux-aarch64" else "unsupported"
    else if nixSystem == "aarch64-linux" then
      "linux-sbsa"
    else if nixSystem == "x86_64-linux" then
      "linux-x86_64"
    else if nixSystem == "powerpc64le-linux" then
      "linux-ppc64le"
    else if nixSystem == "x86_64-windows" then
      "windows-x86_64"
    else
      "unsupported";

  /**
    Generates a CUDA variant name from a version.

    # Example

    ```nix
    cuda-lib.utils.mkCudaVariant "11.0"
    => "cuda11"
    ```

    # Type

    ```
    mkCudaVariant :: String -> String
    ```

    # Arguments

    version
    : The version string
  */
  mkCudaVariant = version: "cuda${major version}";

  /**
    Generates a filtered `Redists` given a `MajorMinorPatchVersion` for CUDA.

    # Type

    ```
    mkFilteredRedists :: MajorMinorPatchVersion -> Redists -> Redists
    ```

    # Arguments

    cudaMajorMinorPatchVersion
    : The CUDA version to filter by

    redists
    : The `Redists` value to filter
  */
  mkFilteredRedists =
    cudaMajorMinorPatchVersion: redists:
    # NOTE: Here's what's happening with this particular mess of code:
    #       Working from the inside out, at each level we're filter the attribute set, removing packages which
    #       won't work with the current CUDA version.
    #       One level up, we're using mapAttrs to set the values of the attribute set equal to the newly filtered
    #       attribute set. We then pass this newly mapAttrs-ed attribute set to filterAttrs again, removing any
    #       empty attribute sets.
    filterAttrs (_: redistConfig: { } != redistConfig.versionedManifests) (
      mapAttrs (
        redistName: redistConfig:
        redistConfig
        // {
          versionedManifests = filterAttrs (_: manifest: { } != manifest) (
            mapAttrs (
              version: manifest:
              filterAttrs (_: release: { } != release.packages) (
                mapAttrs (
                  packageName: release:
                  release
                  // {
                    packages = filterAttrs (_: packageVariants: { } != packageVariants) (
                      mapAttrs (
                        redistArch: packageVariants:
                        filterAttrs (
                          cudaVariant: packageInfo:
                          packageSatisfiesRedistRequirements cudaMajorMinorPatchVersion {
                            inherit
                              cudaVariant
                              packageInfo
                              packageName
                              redistArch
                              redistName
                              version
                              ;
                            inherit (release) releaseInfo;
                          }
                        ) packageVariants
                      ) release.packages
                    );
                  }
                ) manifest
              )
            ) redistConfig.versionedManifests
          );
        }
      ) redists
    );

  /**
    Function to flatten a `Redists` value into a list of `FlattenedRedistsElem`.

    # Type

    ```
    mkFlattenedRedists :: Redists -> List FlattenedRedistsElem
    ```

    # Arguments

    redists
    : The `Redists` to flatten
  */
  mkFlattenedRedists = mapPackageInfoRedistsToList id;

  /**
    Utility function to generate a set of badPlatformsConditions for missing packages.

    Used to mark a package as unsupported if any of its required packages are missing (null).

    Expects a set of attributes.

    Most commonly used in overrides files on a callPackage-provided attribute set of packages.

    NOTE: We use badPlatformsConditions instead of brokenConditions because the presence of packages set to null
    means evaluation will fail if package attributes are accessed without checking for null first. OfBorg
    evaluation sets allowBroken to true, which means we can't rely on brokenConditions to prevent evaluation of
    a package with missing dependencies.

    # Example

    ```nix
    {
      lib,
      libcal ? null,
      libcublas,
      utils,
    }:
    prevAttrs: {
      badPlatformsConditions =
        prevAttrs.badPlatformsConditions
        // utils.mkMissingPackagesBadPlatformsConditions { inherit libcal; };
    }
    ```

    # Type

    ```
    mkMissingPackagesBadPlatformsConditions :: AttrSet -> AttrSet
    ```

    # Arguments

    attrs
    : The attributes to check for null
  */
  mkMissingPackagesBadPlatformsConditions =
    attrs:
    pipe attrs [
      # Take the attributes that are null.
      (filterAttrs (_: value: value == null))
      # Map them to a set of badPlatformsConditions.
      (mapAttrs' (
        name: value: {
          name = "Required package ${name} is missing";
          value = true;
        }
      ))
    ];

  /**
    Helper function to reduce the number of attribute sets we need to traverse to create all the package sets.
    Since the CUDA redistributables make up the largest number of packages in a `Redists` value, we can save time by
    flattening the `Redists` which does not contain CUDA redistributables, and reusing it for each version of CUDA.
    Additionally, we flatten only the CUDA redistributables for the version of CUDA we're currently processing.

    # Type

    ```
    mkTrimmedRedists :: MajorMinorPatchVersion -> Redists -> Redists
    ```

    # Arguments

    cudaMajorMinorPatchVersion
    : The CUDA version to filter by

    redists
    : The `Redists` to filter
  */
  mkTrimmedRedists =
    cudaMajorMinorPatchVersion: redists:
    redists
    // optionalAttrs (redists ? cuda) {
      cuda = redists.cuda // {
        versionedManifests =
          optionalAttrs (redists.cuda.versionedManifests ? ${cudaMajorMinorPatchVersion})
            { ${cudaMajorMinorPatchVersion} = redists.cuda.versionedManifests.${cudaMajorMinorPatchVersion}; };
      };
    };

  /**
    Function to generate a versioned package name.

    Expects a redistName, packageName, and version.

    NOTE: version should come from releaseInfo when taking arguments from a flattenedRedistsElem, as the top-level
    version attribute is the version of the manifest.

    # Type

    ```
    mkVersionedPackageName :: { packageName :: PackageName
                              , redistName :: RedistName
                              , version :: Version
                              , versionPolicy :: VersionPolicy
                              }
                           -> PackageName
    ```

    # Arguments

    packageName
    : The name of the package

    redistName
    : The name of the redistributable

    version
    : The version of the package

    versionPolicy
    : The version policy to use
  */
  mkVersionedPackageName =
    {
      packageName,
      redistName,
      version,
      versionPolicy,
    }:
    if redistName == "cuda" then
      # CUDA redistributables don't have versioned package names.
      packageName
    else
      # Everything else does.
      pipe version [
        (versionPolicyToVersionFunction versionPolicy)
        # Drop dots and replace them with underscores in the version.
        (replaceStrings [ "." ] [ "_" ])
        # Append the version to the package name.
        (version: "${packageName}_${version}")
      ];

  /**
    Filters a `VersionedManifests` attribute set by a version policy, keeping only the latest version of each manifest,
    as determined by the version policy.

    # Type

    ```
    newestVersionedManifestsByVersionPolicy :: VersionPolicy -> VersionedManifests -> VersionedManifests
    ```

    # Arguments

    versionPolicy
    : The version policy to use

    versionedManifests
    : The `VersionedManifests` to filter
  */
  newestVersionedManifestsByVersionPolicy =
    versionPolicy:
    let
      versionFunction = versionPolicyToVersionFunction versionPolicy;
    in
    versionedManifests:
    let
      newestVersionsByVersionPolicy = groupBy' (
        a: b: if versionOlder a b then b else a
      ) "0.0.0.0" versionFunction (attrNames versionedManifests);
    in
    if versionedManifests == { } then
      { }
    else
      genAttrs (attrValues newestVersionsByVersionPolicy) (version: versionedManifests.${version});

  /**
    Function to determine if a package satisfies the redistributable requirements for a given redistributable.
    Expects a cudaMajorMinorPatchVersion and a flattenedRedistsElem.
    Returns an attribute set of conditions, which when any are true, indicate the package does not satisfy a particular
    condition.

    # Type

    ```
    packageSatisfiesRedistRequirements :: String -> FlattenedRedistsElem -> Bool
    ```

    # Arguments

    cudaMajorMinorPatchVersion
    : The CUDA version to filter by

    flattenedRedistsElem
    : The element to check
  */
  packageSatisfiesRedistRequirements =
    cudaMajorMinorPatchVersion:
    {
      cudaVariant,
      packageInfo,
      redistArch,
      redistName,
      version,
      ...
    }:
    let
      inherit (packageInfo.features) cudaVersionsInLib;

      # One of the subdirectories of the lib directory contains a supported version for our version of CUDA.
      # This is typically found with older versions of redistributables which don't use separate tarballs for each
      # supported CUDA version.
      hasSupportedCudaVersionInLib = (getLibPath cudaMajorMinorPatchVersion cudaVersionsInLib) != null;

      # There is a variant for the desired CUDA version.
      isDesiredCudaVariant = cudaVariant == (mkCudaVariant cudaMajorMinorPatchVersion);

      # Helpers
      cudaOlder = versionOlder cudaMajorMinorPatchVersion;
      cudaAtLeast = versionAtLeast cudaMajorMinorPatchVersion;

      # Default value for packages which don't specify some policy.
      default = isDesiredCudaVariant || hasSupportedCudaVersionInLib;
    in
    # Source packages are built on all platforms.
    # NOTE: Source packages are responsible for ensuring they depend on the correct version of their dependencies
    #       -- they may not be the default version available in the package set!
    if redistArch == "source" then
      true

    # CUBLASMP: Only packaged to support redistributables for CUDA 11.4 and later.
    # https://docs.nvidia.com/cuda/cublasmp/getting_started/index.html
    else if redistName == "cublasmp" then
      cudaAtLeast "11.4" && isDesiredCudaVariant

    # CUDA: None of the CUDA redistributables have CUDA variants, but we only need to check that the release
    # version matches the CUDA version we want.
    else if redistName == "cuda" then
      version == cudaMajorMinorPatchVersion

    # CUDNN: Since cuDNN 8.5, it is possible to use the dynamic library for a CUDA release with any CUDA version
    # in that major release series. For example, the cuDNN 8.5 dynamic library for CUDA 11.0 can be used with
    # any CUDA 11.x release. (This functionality is not present for the CUDA 10.2 releases.)
    # As such, it is enough that the cuda variant matches to accept the package.
    else if redistName == "cudnn" then
      # CUDNN requires libcublasLt.so, which was introduced with CUDA 10.1, so we don't support CUDA 10.0.
      cudaAtLeast "10.1" && isDesiredCudaVariant

    # TODO: Create constraint.
    else if redistName == "cudss" then
      default

    # CUQUANTUM: Only available for CUDA 11.4 and later.
    else if redistName == "cuquantum" then
      # Releases prior to 23.03 are only compatible with CUDA 11 -- they look for libnames with
      # a .11 suffix.
      # They also don't provide CUDA versions in lib or cuda variants.
      if versionOlder version "23.03.0" then
        cudaAtLeast "11.4" && cudaOlder "12.0"

      # Releases including and after 23.03 provide CUDA versions in lib or cuda variants.
      else
        isDesiredCudaVariant || hasSupportedCudaVersionInLib

    # TODO: Create constraint.
    else if redistName == "cusolvermp" then
      default

    # CUSPARSELT:
    # Versions prior to 0.5.0 support CUDA 11.x (which we restrict to 11.4 and later).
    # Versions including and after 0.5.0 support only CUDA 12.0.
    # https://docs.nvidia.com/cuda/cusparselt/release_notes.html
    else if redistName == "cusparselt" then
      if versionAtLeast version "0.5.0" then
        cudaAtLeast "12.0"
      else
        cudaAtLeast "11.4" && cudaOlder "12.0"

    # CUTENSOR: Instead of providing CUDA variants, cuTensor provides multiple versions of the library nested
    # in the lib directory. So long as one of the versions in cudaVersionsInLib is a prefix of the current CUDA
    # version, we accept the package. We should have a more stringent version check, but no one has written
    # a sidecar file mapping releases to supported CUDA versions.
    else if redistName == "cutensor" then
      hasSupportedCudaVersionInLib

    # TODO: Create constraint.
    else if redistName == "nppplus" then
      default

    # TODO: Create constraint.
    else if redistName == "nvidia-driver" then
      default

    # TODO: Create constraint.
    else if redistName == "nvjpeg2000" then
      default

    # TODO: Create constraint.
    else if redistName == "nvpl" then
      default

    # TODO: Create constraint.
    else if redistName == "nvtiff" then
      default

    # TODO: Create constraint.
    else if redistName == "tensorrt" then
      default

    # NOTE: We must be total.
    else
      builtins.throw "Unsupported NVIDIA redistributable: ${redistName}";

  /**
    Returns true if a version policy is at least as specific (has at least as many components) as another version
    policy.

    # Type

    ```
    versionPolicyAtLeast :: VersionPolicy -> VersionPolicy -> Bool
    ```

    # Arguments

    versionPolicy1
    : The first version policy

    versionPolicy2
    : The second version policy
  */
  versionPolicyAtLeast =
    versionPolicy1: versionPolicy2:
    versionPolicyToNumComponents versionPolicy1 >= versionPolicyToNumComponents versionPolicy2;

  /**
    Maps a `VersionPolicy` to the number of components in the version.

    # Type

    ```
    versionPolicyToNumComponents :: VersionPolicy -> Natural
    ```

    # Arguments

    versionPolicy
    : The version policy
  */
  versionPolicyToNumComponents =
    versionPolicy:
    if versionPolicy == "major" then
      1
    else if versionPolicy == "minor" then
      2
    else if versionPolicy == "patch" then
      3
    else if versionPolicy == "build" then
      4
    else
      builtins.throw "Unsupported version policy: ${versionPolicy}";

  /**
    Function to generate a version function from a version policy.

    Expects a version policy and returns a version function.

    # Type

    ```
    versionPolicyToVersionFunction :: VersionPolicy -> String -> Version
    ```

    # Arguments

    versionPolicy
    : The version policy
  */
  versionPolicyToVersionFunction =
    versionPolicy:
    if versionPolicy == "major" then
      major
    else if versionPolicy == "minor" then
      majorMinor
    else if versionPolicy == "patch" then
      majorMinorPatch
    else if versionPolicy == "build" then
      majorMinorPatchBuild
    else
      builtins.throw "Unsupported version policy: ${versionPolicy}";
}
