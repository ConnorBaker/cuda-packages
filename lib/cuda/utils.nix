{ lib }:
let
  inherit (builtins) readDir;
  inherit (lib.cuda.data) redistUrlPrefix;
  inherit (lib.cuda.utils)
    getLibPath
    mkRedistUrl
    mkRelativePath
    mkTensorRTUrl
    readDirIfExists
    ;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets)
    attrNames
    filterAttrs
    foldlAttrs
    hasAttr
    mapAttrs
    mapAttrs'
    optionalAttrs
    ;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.licenses) nvidiaCudaRedist;
  inherit (lib.lists)
    concatMap
    elem
    filter
    findFirst
    head
    optionals
    intersectLists
    reverseList
    unique
    ;
  inherit (lib.options) mkOption;
  inherit (lib.strings)
    concatStringsSep
    hasPrefix
    hasSuffix
    removeSuffix
    ;
  inherit (lib.trivial)
    const
    flip
    importJSON
    mapNullable
    pipe
    ;
  inherit (lib.upstreamable.types) version;
  inherit (lib.versions) major majorMinor;
in
{
  inherit (lib.upstreamable.attrsets)
    attrPaths
    drvAttrPaths
    flattenAttrs
    flattenDrvTree
    ;
  inherit (lib.upstreamable.strings)
    versionAtMost
    versionNewer
    versionBoundedExclusive
    versionBoundedInclusive
    ;
  inherit (lib.upstreamable.trivial) readDirIfExists;
  inherit (lib.upstreamable.versions)
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
    Helper function to build a `redistConfig`.

    # Type

    ```
    mkRedistConfig :: Path -> RedistConfig
    ```

    # Arguments

    path
    : The path to the redistributable directory
  */
  mkRedistConfig = path: {
    versionedOverrides = mapAttrs (
      pathName: pathType:
      let
        cursor = path + "/overrides/${pathName}";
      in
      assert assertMsg (
        pathType == "directory"
      ) "mkRedistConfig: expected a directory at ${cursor} but found ${pathType}";
      assert assertMsg (version.check pathName)
        "mkRedistConfig: expected directory name ${pathName} at ${cursor} to be a version";
      packagesFromDirectoryRecursive {
        # Function which loads the file as a Nix expression and ignores the second argument.
        # NOTE: We don't actually want to callPackage these functions at this point, so we use builtins.import
        # instead. We do, however, have to match the callPackage signature.
        callPackage = path: _: path;
        directory = cursor;
      }
    ) (readDirIfExists (path + "/overrides"));
    versionedManifests = mapAttrs' (
      pathName: pathType:
      let
        cursor = path + "/manifests/${pathName}";
        fileName = removeSuffix ".json" pathName;
      in
      assert assertMsg (
        pathType == "regular"
      ) "mkRedistConfig: expected a file at ${cursor} but found ${pathType}";
      assert assertMsg (hasSuffix ".json" pathName) "mkRedistConfig: expected a JSON file at ${cursor}";
      assert assertMsg (version.check fileName)
        "mkRedistConfig: expected file name ${fileName} at ${cursor} to be a version";
      {
        name = removeSuffix ".json" pathName;
        value = importJSON cursor;
      }
    ) (readDir (path + "/manifests"));
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
    mkRelativePath :: { cudaVariant :: CudaVariant
                      , packageName :: PackageName
                      , redistArch :: RedistArch
                      , redistName :: RedistName
                      , relativePath :: NullOr NonEmptyStr
                      , releaseInfo :: ReleaseInfo
                      }
                   -> String
    ```

    # Arguments

    cudaVariant
    : The CUDA variant of the package

    packageName
    : The name of the package

    redistArch
    : The redist architecture of the package

    redistName
    : The name of the redistributable

    relativePath
    : An optional relative path to the redistributable, defaults to null

    releaseInfo
    : The release information of the package
  */
  mkRelativePath =
    {
      cudaVariant,
      packageName,
      redistArch,
      redistName,
      relativePath ? null,
      releaseInfo,
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
    Function to build redistributable packages.

    # Type

    ```
    buildRedistPackages :: { desiredCudaVariant :: CudaVariant
                           , finalCudaPackages :: Attrs
                           , hostRedistArch :: RedistArch
                           , manifest :: Version
                           , redistName :: RedistName
                           }
                        -> Attrs
    ```

    # Arguments

    desiredCudaVariant
    : The desired CUDA variant

    finalCudaPackages
    : The fixed-point of the package set

    hostRedistArch
    : The redistributable architecture of the host

    manifestVersion
    : The manifest version to build packages from

    redistName
    : The name of the redistributable package set
  */
  buildRedistPackages =
    {
      desiredCudaVariant,
      finalCudaPackages,
      hostRedistArch,
      manifestVersion,
      redistConfig,
      redistName,
    }:
    let
      versionedManifest = redistConfig.versionedManifests.${manifestVersion};
      callPackageOverriders = redistConfig.versionedOverrides.${manifestVersion} or { };
    in
    foldlAttrs (
      acc:
      # Package name
      packageName:
      # A release, which is a collection of the package for different architectures and CUDA versions, along with
      # release information.
      { packages, releaseInfo }:
      let
        # Names of redistributable architectures for the package which provide a release for the current CUDA version.
        supportedRedistArchs = filter (
          redistArch:
          let
            packageVariants = packages.${redistArch};
          in
          hasAttr "None" packageVariants || hasAttr desiredCudaVariant packageVariants
        ) (attrNames packages);
        supportedNixPlatforms = unique (concatMap lib.cuda.utils.getNixPlatforms supportedRedistArchs);

        # NOTE: We must check for compatibility with the redistributable architecture, not the Nix platform,
        #       because the redistributable architecture is able to disambiguate between aarch64-linux with and
        #       without Jetson support (`linux-aarch64` and `linux-sbsa`, respectively).
        nixPlatformIsSupported = elem hostRedistArch supportedRedistArchs;

        # Choose the source release by default, if it exists.
        # If it doesn't and our platform is supported, use the host redistributable architecture.
        # Otherwise, use whatever is first in the list of supported redistributable architectures -- the package won't be valid
        # on the host platform, but we will at least have an entry for it.
        redistArch =
          if hasAttr "source" packages then
            "source"
          else if nixPlatformIsSupported then
            hostRedistArch
          else
            head supportedRedistArchs;
        packageVariants = packages.${redistArch};

        # Choose the version without a CUDA variant by default, if it exists.
        cudaVariant = if hasAttr "None" packageVariants then "None" else desiredCudaVariant;
        packageInfo = packageVariants.${cudaVariant};
        libPath = getLibPath finalCudaPackages.cudaMajorMinorPatchVersion packageInfo.features.cudaVersionsInLib;
        # The source is given by the tarball, which we unpack and use as a FOD.
        src = finalCudaPackages.pkgs.fetchzip {
          url =
            if redistName == "tensorrt" then
              mkTensorRTUrl packageInfo.relativePath
            else
              mkRedistUrl redistName (mkRelativePath {
                inherit
                  cudaVariant
                  packageName
                  redistArch
                  redistName
                  releaseInfo
                  ;
                inherit (packageInfo) relativePath;
              });
          hash = packageInfo.recursiveHash;
        };

        maybeCallPackageOverrider = callPackageOverriders.${packageName} or null;

        redistBuilderArgs = {
          inherit
            libPath
            packageInfo
            packageName
            releaseInfo
            src
            ;
        };

        package = pipe redistBuilderArgs (
          [
            # Build the package
            finalCudaPackages.redist-builder
            # Update meta with the list of supported platforms and fix the license URL
            (
              pkg:
              pkg.overrideAttrs (prevAttrs: {
                src = if nixPlatformIsSupported then prevAttrs.src else null;
                outputs = if nixPlatformIsSupported then prevAttrs.outputs else [ "out" ];
                meta = prevAttrs.meta // {
                  platforms = supportedNixPlatforms;
                  license = nvidiaCudaRedist // {
                    url =
                      let
                        licensePath =
                          if releaseInfo.licensePath != null then releaseInfo.licensePath else "${packageName}/LICENSE.txt";
                      in
                      "https://developer.download.nvidia.com/compute/${redistName}/redist/${licensePath}";
                  };
                };
              })
            )
          ]
          # Apply optional fixups
          ++ optionals (maybeCallPackageOverrider != null) [
            (pkg: pkg.overrideAttrs (finalCudaPackages.callPackage maybeCallPackageOverrider { }))
          ]
        );
      in
      acc
      // optionalAttrs (supportedRedistArchs != [ ]) {
        ${packageName} = package;
      }
    ) { } versionedManifest;

  /**
    Returns the path to the CUDA library directory for a given version or null if no such version exists.

    Implementation note: Find the first libPath in the list of cudaVersionsInLib that is a prefix of the current cuda
    version.

    # Example

    ```nix
    lib.cuda.utils.getLibPath "11.0" null
    => null
    ```

    ```nix
    lib.cuda.utils.getLibPath "11.0" [ "10.2" "11" "11.0" "12" ]
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
    lib.cuda.utils.getNixPlatforms "linux-sbsa"
    => [ "aarch64-linux" ]
    ```

    ```nix
    lib.cuda.utils.getNixPlatforms "linux-aarch64"
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
    lib.cuda.utils.getRedistArch true "aarch64-linux"
    => "linux-aarch64"
    ```

    ```nix
    lib.cuda.utils.getRedistArch false "aarch64-linux"
    => "linux-sbsa"
    ```

    ```nix
    lib.cuda.utils.getRedistArch false "powerpc64le-linux"
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
    lib.cuda.utils.mkCudaVariant "11.0"
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

  mkRealArchitecture = cudaCapability: "sm_" + lib.cuda.utils.dropDots cudaCapability;
  mkVirtualArchitecture = cudaCapability: "compute_" + lib.cuda.utils.dropDots cudaCapability;

  # This is used solely for utility functions getNixPlatform and getRedistArch which are needed before the flags
  # attribute set of values and functions is created in the package fixed-point.
  getJetsonTargets =
    gpus: cudaCapabilities:
    let
      allJetsonComputeCapabilities = concatMap (
        gpu: optionals gpu.isJetson [ gpu.computeCapability ]
      ) gpus;
    in
    intersectLists allJetsonComputeCapabilities cudaCapabilities;
  # TODO: Move to doc.
  # jetsonTargets = {
  #   description = "List of Jetson targets";
  #   type = listOf lib.cuda.types.cudaCapability;
  #   default =
  #     let
  #       allJetsonComputeCapabilities = concatMap (
  #         gpu: optionals gpu.isJetson [ gpu.computeCapability ]
  #       ) config.data.gpus;
  #     in
  #     intersectLists allJetsonComputeCapabilities config.cuda.capabilities;
  # };
}
