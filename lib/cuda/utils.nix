{ lib }:
let
  inherit (builtins) readDir;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets)
    attrNames
    attrValues
    filterAttrs
    foldlAttrs
    genAttrs
    hasAttr
    isAttrs
    isDerivation
    mapAttrs
    mapAttrs'
    optionalAttrs
    recursiveUpdate
    ;
  inherit (lib.cuda.data) redistUrlPrefix;
  inherit (lib.cuda.utils)
    dropDots
    getLibPath
    getNixPlatforms
    getSupportedRedistArchs
    mkAarch64BadPlatformsConditions
    mkCudaPackagesCallPackage
    mkCudaPackagesScope
    mkCudaPackagesOverrideAttrsDefaultsFn
    mkOptions
    mkRedistUrl
    mkRelativePath
    mkVersionedManifests
    mkVersionedOverrides
    packageExprPathsFromDirectoryRecursive
    readDirIfExists
    versionAtMost
    ;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.fixedPoints) extends;
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
    concatMapStringsSep
    concatStringsSep
    hasPrefix
    hasSuffix
    removeSuffix
    versionAtLeast
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
    Creates an options module from an attribute set of options by mapping `mkOption` over the values of the attribute
    set.

    # Type

    ```
    mkOptionsModule :: AttrSet -> AttrSet
    ```

    # Arguments

    attrs
    : An attribute set
  */
  mkOptionsModule = attrs: { options = mkOptions attrs; };

  /**
    Helper function to build a `redistConfig`.

    # Type

    ```
    mkRedistConfig :: Path -> RedistConfig
    ```

    # Arguments

    path
    : The path to the redistributable directory containing a `manifests` directory and (optionally) an `overrides`
      directory.
  */
  mkRedistConfig =
    path:
    let
      versionedManifests = mkVersionedManifests (path + "/manifests");
      versions = attrNames versionedManifests;
    in
    {
      inherit versionedManifests;
      versionedOverrides = mkVersionedOverrides versions (path + "/overrides");
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
    redistName: relativePath:
    concatStringsSep "/" (
      [
        redistUrlPrefix
      ]
      ++ (
        if redistName != "tensorrt" then
          [
            redistName
            "redist"
          ]
        else
          [ "machine-learning" ]
      )
      ++ [
        relativePath
      ]
    );

  /**
    Function to recreate a relative path for a redistributable.

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
    if relativePath != null then
      relativePath
    else
      assert assertMsg (redistName != "tensorrt")
        "mkRelativePath: tensorrt does not use standard naming conventions for relative paths and requires relativePath be non-null";
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
    Function to produce `versionedManifests`.

    # Type

    ```
    mkVersionedManifests :: Directory -> VersionedManifests
    ```

    # Arguments

    directory
    : Path to directory containing manifests
  */
  mkVersionedManifests =
    path:
    mapAttrs' (
      pathName: pathType:
      let
        cursor = path + "/${pathName}";
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
    ) (readDir path);

  /**
    Function to produce `versionedOverrides`.

    # Type

    ```
    mkVersionedOverrides :: Directory -> VersionedOverrides
    ```

    # Arguments

    versions
    : Versions to populate with `common` in the case the directory contains only `common`

    directory
    : Path to directory containing overrides grouped by version.
      May optionally contain a `common` directory which is shared between all versions, where overrides from a version
      take priority.
  */
  mkVersionedOverrides =
    versions: path:
    let
      overridesDir = readDirIfExists path;
      # Special handling for `common`, which is shared with all versions.
      common = optionalAttrs (overridesDir ? common) (
        let
          cursor = path + "/common";
        in
        assert assertMsg (
          overridesDir.common == "directory"
        ) "mkRedistConfig: expected a directory at ${cursor} but found ${overridesDir.common}";
        packageExprPathsFromDirectoryRecursive cursor
      );
    in
    genAttrs versions (
      version:
      let
        cursor = path + "/${version}";
        # If null, `pathType` indicates we should use only `common`.
        pathType = overridesDir.${version} or null;
        overrides = optionalAttrs (pathType != null) (packageExprPathsFromDirectoryRecursive cursor);
      in
      assert assertMsg (
        pathType == null || pathType == "directory"
      ) "mkRedistConfig: expected a directory at ${cursor} but found ${pathType}";
      # NOTE: Overrides for the specific version take precedence over those in `common`.
      common // overrides
    );

  /**
    Much like `packagesFromDirectoryRecursive`, except instead of invoking `callPackage` on the leaves, this function
    leaves them as paths.

    # Type

    ```
    packageExprPathsFromDirectoryRecursive :: Directory -> Attrs
    ```

    # Arguments

    directory
    : The directory to recurse into
  */
  packageExprPathsFromDirectoryRecursive =
    directory:
    packagesFromDirectoryRecursive {
      inherit directory;
      callPackage = path: _: path;
    };

  /**
    Much like `packagesFromDirectoryRecursive`, except instead of invoking `callPackage` on the leaves, this function
    `import`s them.

    # Type

    ```
    packageExprsFromDirectoryRecursive :: Directory -> Attrs
    ```

    # Arguments

    directory
    : The directory to recurse into
  */
  packageExprsFromDirectoryRecursive =
    directory:
    packagesFromDirectoryRecursive {
      inherit directory;
      callPackage = path: _: import path;
    };

  # TODO: Alphabetize

  /**
    Function to build redistributable packages.

    NOTE: Curried to allow partial application.

    # Type

    ```
    buildRedistPackages :: { desiredCudaVariant :: CudaVariant
                           , finalCudaPackages :: Attrs
                           , hostRedistArch :: RedistArch
                           }
                        -> { callPackageOverriders :: Attrs
                           , manifest :: Manifest
                           , redistName :: RedistName
                           }
                        -> Attrs
    ```

    # Arguments

    callPackageOverriders
    : An attribute set of paths which can be `callPackage`-d and supplied to a package's `overrideAttrs` function.

    desiredCudaVariant
    : The desired CUDA variant

    finalCudaPackages
    : The fixed-point of the package set

    hostRedistArch
    : The redistributable architecture of the host

    manifest
    : The manifest of a redistributable package set

    redistName
    : The name of the redistributable package set
  */
  buildRedistPackages =
    {
      desiredCudaVariant,
      finalCudaPackages,
      hostRedistArch,
    }:
    let
      inherit (finalCudaPackages)
        callPackage
        cudaMajorMinorPatchVersion
        redist-builder
        ;
      inherit (finalCudaPackages.flags) isJetsonBuild;
      inherit (finalCudaPackages.pkgs) fetchzip stdenv;
      isNixHostPlatformSystemAarch64 = stdenv.hostPlatform.isAarch64;
      overrideAttrsDefaultsFn = mkCudaPackagesOverrideAttrsDefaultsFn finalCudaPackages;
    in
    {
      callPackageOverriders,
      manifest,
      redistName,
    }:
    foldlAttrs (
      acc:
      # Package name
      packageName:
      # A release, which is a collection of the package for different architectures and CUDA versions, along with
      # release information.
      # NOTE: `packages` and `releaseInfo` correspond to types of the same name in lib.cuda.types.
      { packages, releaseInfo }:
      let
        # Names of redistributable architectures for the package which provide a release for the current CUDA version.
        supportedRedistArchs = getSupportedRedistArchs packages desiredCudaVariant;
        supportedNixPlatforms = unique (concatMap getNixPlatforms supportedRedistArchs);

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
        libPath = getLibPath cudaMajorMinorPatchVersion packageInfo.features.cudaVersionsInLib;

        # The source is given by the tarball, which we unpack and use as a FOD.
        src = fetchzip {
          url = mkRedistUrl redistName (mkRelativePath {
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
            redist-builder
            # Apply our defaults
            (pkg: pkg.overrideAttrs overrideAttrsDefaultsFn)
            # Update meta with the list of supported platforms and fix the license URL
            (
              pkg:
              pkg.overrideAttrs (prevAttrs: {
                # When `src` is `null`, `redist-builder` will mark the package as unavailable on the platform.
                src = if nixPlatformIsSupported then prevAttrs.src else null;
                outputs = if nixPlatformIsSupported then prevAttrs.outputs else [ "out" ];
                passthru =
                  if !isNixHostPlatformSystemAarch64 then
                    prevAttrs.passthru or { }
                  else
                    recursiveUpdate (prevAttrs.passthru or { }) {
                      badPlatformsConditions = mkAarch64BadPlatformsConditions isJetsonBuild supportedRedistArchs;
                    };
                meta = recursiveUpdate (prevAttrs.meta or { }) {
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
            (pkg: pkg.overrideAttrs (callPackage maybeCallPackageOverrider { }))
          ]
        );
      in
      acc
      // optionalAttrs (supportedRedistArchs != [ ]) {
        ${packageName} = package;
      }
    ) { } manifest;

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
    # NOTE: Attribute name lookup is logarithmic, while if-then-else is linear.
    let
      attrs = {
        linux-sbsa = [ "aarch64-linux" ];
        linux-aarch64 = [ "aarch64-linux" ];
        linux-x86_64 = [ "x86_64-linux" ];
        linux-ppc64le = [ "powerpc64le-linux" ];
        source = [
          "aarch64-linux"
          "powerpc64le-linux"
          "x86_64-linux"
          "x86_64-windows"
        ];
        windows-x86_64 = [ "x86_64-windows" ];
      };
    in
    redistArch: attrs.${redistArch} or [ "unsupported" ];

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
    let
      attrs = {
        x86_64-linux = "linux-x86_64";
        powerpc64le-linux = "linux-ppc64le";
        x86_64-windows = "windows-x86_64";
      };
    in
    isJetsonBuild:
    let
      attrs' = attrs // {
        aarch64-linux = if isJetsonBuild then "linux-aarch64" else "linux-sbsa";
      };
    in
    nixSystem: attrs'.${nixSystem} or "unsupported";

  /**
    TODO:
  */
  getSupportedRedistArchs =
    packages: desiredCudaVariant:
    filter (
      redistArch:
      let
        packageVariants = packages.${redistArch};
      in
      hasAttr "None" packageVariants || hasAttr desiredCudaVariant packageVariants
    ) (attrNames packages);

  /**
    Returns whether a GPU should be built by default for a particular CUDA version.

    TODO:
  */
  gpuIsDefault =
    cudaMajorMinorVersion: gpuInfo:
    let
      inherit (gpuInfo) dontDefaultAfterCudaMajorMinorVersion isJetson;
      recentGpu =
        dontDefaultAfterCudaMajorMinorVersion == null
        || versionAtLeast dontDefaultAfterCudaMajorMinorVersion cudaMajorMinorVersion;
    in
    recentGpu && !isJetson;

  /**
    Returns whether a GPU is supported for a particular CUDA version.

    TODO:
  */
  gpuIsSupported =
    cudaMajorMinorVersion: gpuInfo:
    let
      inherit (gpuInfo) minCudaMajorMinorVersion maxCudaMajorMinorVersion;
      lowerBoundSatisfied = versionAtLeast cudaMajorMinorVersion minCudaMajorMinorVersion;
      upperBoundSatisfied =
        (maxCudaMajorMinorVersion == null)
        || (versionAtMost cudaMajorMinorVersion maxCudaMajorMinorVersion);
    in
    lowerBoundSatisfied && upperBoundSatisfied;

  /**
    TODO:
  */
  mkAarch64BadPlatformsConditions =
    isJetsonBuild: supportedRedistArchs:
    let
      isRedistArchSbsaExplicitlySupported = elem "linux-sbsa" supportedRedistArchs;
      isRedistArchAarch64ExplicitlySupported = elem "linux-aarch64" supportedRedistArchs;
    in
    {
      "aarch64-linux support is limited to linux-sbsa (server ARM devices) which is not the current target" =
        isRedistArchSbsaExplicitlySupported && !isRedistArchAarch64ExplicitlySupported && isJetsonBuild;
      "aarch64-linux support is limited to linux-aarch64 (Jetson devices) which is not the current target" =
        !isRedistArchSbsaExplicitlySupported && isRedistArchAarch64ExplicitlySupported && !isJetsonBuild;
    };

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
    TODO:
  */
  # TODO(@connorbaker):
  # - Aliases for backendStdenv, backendStdenv.cc.
  # - Remove stdenv = cudaStdenv and update comment for __structuredAttrs = false.
  # - Don't propagate nixLogWithLevelAndFunctionHook or noBrokenSymlinksHook.
  # Manual definition of callPackage which will set certain attributes for us within the package set.
  # Definition comes from the implementation of lib.customisation.makeScope:
  # https://github.com/NixOS/nixpkgs/blob/9f4fd5626d7aa9a376352fc244600c894b5a0c79/lib/customisation.nix#L608
  mkCudaPackagesCallPackage =
    finalCudaPackages:
    let
      inherit (finalCudaPackages) newScope;
      overrideAttrsFn = mkCudaPackagesOverrideAttrsDefaultsFn finalCudaPackages;
    in
    fn: args:
    let
      result = newScope { } fn args;
    in
    if isAttrs result && isDerivation result then result.overrideAttrs overrideAttrsFn else result;

  /**
    TODO:
  */
  # TODO(@connorbaker):
  mkCudaPackagesOverrideAttrsDefaultsFn =
    finalCudaPackages:
    let
      inherit (finalCudaPackages.pkgs) nixLogWithLevelAndFunctionNameHook noBrokenSymlinksHook;
      inherit (finalCudaPackages) cudaNamePrefix;
    in
    finalAttrs: prevAttrs: {
      # Default __structuredAttrs and strictDeps to true.
      __structuredAttrs = prevAttrs.__structuredAttrs or true;
      strictDeps = prevAttrs.strictDeps or true;

      # Name should be prefixed by cudaNamePrefix to create more descriptive path names.
      name =
        if finalAttrs ? pname && finalAttrs ? version then
          "${cudaNamePrefix}-${finalAttrs.pname}-${finalAttrs.version}"
        # TODO(@connorbaker): Can't make the final name depend on itself.
        else if (!(hasPrefix cudaNamePrefix prevAttrs.name)) then
          "${cudaNamePrefix}-${prevAttrs.name}"
        else
          prevAttrs.name;

      propagatedBuildInputs =
        let
          prevPropagatedBuildInputs = prevAttrs.propagatedBuildInputs or [ ];
        in
        prevPropagatedBuildInputs
        # We add a hook to replace the standard logging functions.
        ++ optionals (!(elem nixLogWithLevelAndFunctionNameHook prevPropagatedBuildInputs)) [
          nixLogWithLevelAndFunctionNameHook
        ]
        # We add a hook to make sure we're not propagating broken symlinks.
        ++ optionals (!(elem noBrokenSymlinksHook prevPropagatedBuildInputs)) [
          noBrokenSymlinksHook
        ];
    };

  /**
    TODO:
  */
  # Taken and modified from:
  # https://github.com/NixOS/nixpkgs/blob/9f4fd5626d7aa9a376352fc244600c894b5a0c79/lib/customisation.nix#L603-L613
  mkCudaPackagesScope =
    newScope: f:
    let
      finalCudaPackages = f finalCudaPackages // {
        newScope = scope: newScope (finalCudaPackages // scope);
        callPackage = mkCudaPackagesCallPackage finalCudaPackages;
        overrideScope = g: mkCudaPackagesScope newScope (extends g f);
        packages = f;
      };
    in
    finalCudaPackages;

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
    let
      inherit (lib.attrsets) recursiveUpdate;
      inherit (lib.cuda.utils) mkMissingPackagesBadPlatformsConditions;
    in
    prevAttrs: {
      passthru = recursiveUpdate (prevAttrs.passthru or { }) {
        badPlatformsConditions = mkMissingPackagesBadPlatformsConditions { inherit libcal; };
      };
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
  mkMissingPackagesBadPlatformsConditions = flip pipe [
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

  # TODO: DOCS
  mkCmakeCudaArchitecturesString = concatMapStringsSep ";" dropDots;
  mkGencodeFlag =
    targetRealArch: cudaCapability:
    let
      cap = dropDots cudaCapability;
    in
    "-gencode=arch=compute_${cap},code=${if targetRealArch then "sm" else "compute"}_${cap}";
  mkRealArchitecture = cudaCapability: "sm_" + dropDots cudaCapability;
  mkVirtualArchitecture = cudaCapability: "compute_" + dropDots cudaCapability;

  # This is used solely for utility functions getNixPlatform and getRedistArch which are needed before the flags
  # attribute set of values and functions is created in the package fixed-point.
  getJetsonTargets =
    gpus: cudaCapabilities:
    let
      allJetsonComputeCapabilities = concatMap (gpu: optionals gpu.isJetson [ gpu.cudaCapability ]) (
        attrValues gpus
      );
    in
    intersectLists allJetsonComputeCapabilities cudaCapabilities;
}
