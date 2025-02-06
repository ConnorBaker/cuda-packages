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
    nameValuePair
    optionalAttrs
    ;
  inherit (lib.cuda.data) redistUrlPrefix;
  inherit (lib.cuda.types) redistName;
  inherit (lib.cuda.utils)
    bimap
    dotsToUnderscores
    dropDots
    getNixPlatforms
    mkCudaPackagesCallPackage
    mkCudaPackagesOverrideAttrsDefaultsFn
    mkCudaPackagesScope
    mkCudaVariant
    mkOptions
    mkRedistConfig
    mkRedistUrl
    mkRedistUrlRelativePath
    mkVersionedManifests
    mkVersionedOverrides
    packageExprPathsFromDirectoryRecursive
    packagesFromDirectoryRecursive'
    readDirIfExists
    ;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.fixedPoints) extends;
  inherit (lib.lists)
    concatMap
    elem
    filter
    findFirst
    optionals
    intersectLists
    reverseList
    ;
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.strings)
    concatMapStringsSep
    concatStringsSep
    hasPrefix
    hasSuffix
    removeSuffix
    replaceStrings
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
  inherit (lib.upstreamable.trivial) readDirIfExists;
  inherit (lib.upstreamable.versions)
    dropDots
    majorMinorPatch
    ;

  # TODO: DOCS
  collectPackageConfigsForCudaVersion =
    cudaConfig: cudaMajorMinorPatchVersion:
    let
      inherit (cudaConfig) hostRedistArch;
      backupCudaVariant = mkCudaVariant cudaMajorMinorPatchVersion;
      # Get the redist names and versions for our particular package set.
      redistNameToRedistVersion = cudaConfig.cudaPackages.${cudaMajorMinorPatchVersion}.redists;
    in
    concatMap (
      redistName:
      let
        redistVersion = redistNameToRedistVersion.${redistName};
        redistManifest = cudaConfig.redists.${redistName}.versionedManifests.${redistVersion};
        redistCallPackageOverriders = cudaConfig.redists.${redistName}.versionedOverrides.${redistVersion};
      in
      concatMap (
        packageName:
        let
          inherit (redistManifest.${packageName}) releaseInfo packages;
        in
        concatMap (
          redistArch:
          let
            packageVariants = packages.${redistArch};
            # Always show preference to the "source" redistArch if it is available, as it is the most general.
            nixPlatformIsSupported =
              redistArch == "source" || (redistArch == hostRedistArch && !(packages ? source));
          in
          map (
            cudaVariant:
            let
              # Always show preference to the "None" cudaVariant if it is available, as it is the most general.
              packageInfo = packageVariants.${cudaVariant};
              cudaVariantIsSupported =
                cudaVariant == "None" || (cudaVariant == backupCudaVariant && !(packageVariants ? None));
            in
            # If the package variant is supported for this CUDA version, include information about it --
            # it means the package is available for *some* architecture.
            {
              ${packageName} = mkIf cudaVariantIsSupported {
                inherit redistName releaseInfo;
                # Attribute set handles deduplication for us; we use this to create platforms in meta.
                supportedNixPlatformAttrs = genAttrs (getNixPlatforms redistArch) (const null);
                supportedRedistArchAttrs.${redistArch} = null;
                # We want packageInfo to be default here so it can be successfully replaced by the chosen
                # package variant, if it exists.
                packageInfo = if nixPlatformIsSupported then packageInfo else mkDefault packageInfo;
                callPackageOverrider = mkIf nixPlatformIsSupported (
                  redistCallPackageOverriders.${packageName} or null
                );
                srcArgs = mkIf nixPlatformIsSupported {
                  url = mkRedistUrl redistName (mkRedistUrlRelativePath {
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
              };
            }
          ) (attrNames packageVariants)
        ) (attrNames packages)
      ) (attrNames redistManifest)
    ) (attrNames redistNameToRedistVersion);

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

  mkRedistConfigs =
    path:
    foldlAttrs (
      acc: pathName: pathType:
      acc
      // optionalAttrs (pathType == "directory") (
        assert assertMsg (redistName.check pathName) "Expected a redist name but got ${pathName}";
        {
          ${pathName} = mkRedistConfig (path + "/${pathName}");
        }
      )
    ) { } (readDir path);

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
    mkRedistUrlRelativePath
      :: { cudaVariant :: CudaVariant
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
  mkRedistUrlRelativePath =
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
        "mkRedistUrlRelativePath: tensorrt does not use standard naming conventions for relative paths and requires relativePath be non-null";
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

  # Vendored from:
  # https://github.com/NixOS/nixpkgs/blob/eb82888147a6aecb8ae6ee5a685ecdf021b8ed33/lib/filesystem.nix#L385-L416
  # Modified to wrap result of directory traversal in a `recurseIntoAttrs` call and to take arguments positionally.
  packagesFromDirectoryRecursive' =
    callPackage: directory:
    let
      inherit (lib) concatMapAttrs recurseIntoAttrs removeSuffix;
      inherit (lib.path) append;
      defaultPath = append directory "package.nix";
    in
    if builtins.pathExists defaultPath then
      # if `${directory}/package.nix` exists, call it directly
      callPackage defaultPath { }
    else
      recurseIntoAttrs (
        concatMapAttrs (
          name: type:
          # otherwise, for each directory entry
          let
            path = append directory name;
          in
          if type == "directory" then
            # recurse into directories
            { ${name} = packagesFromDirectoryRecursive' callPackage path; }
          else if type == "regular" && hasSuffix ".nix" name then
            # call .nix files
            { ${removeSuffix ".nix" name} = callPackage path { }; }
          else if type == "regular" then
            # ignore non-nix files
            { }
          else
            throw ''
              lib.filesystem.packagesFromDirectoryRecursive: Unsupported file type ${type} at path ${toString path}
            ''
        ) (builtins.readDir directory)
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
    if redistArch == "linux-x86_64" then
      [ "x86_64-linux" ]
    else if redistArch == "linux-sbsa" then
      [ "aarch64-linux" ]
    else if redistArch == "linux-aarch64" then
      [ "aarch64-linux" ]
    else
      [ ];

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
    if nixSystem == "x86_64-linux" then
      "linux-x86_64"
    else if nixSystem == "aarch64-linux" then
      if isJetsonBuild then "linux-aarch64" else "linux-sbsa"
    else
      "unsupported";

  /**
    TODO:
  */
  getSupportedRedistArches =
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
        || (versionAtLeast maxCudaMajorMinorVersion cudaMajorMinorVersion);
    in
    lowerBoundSatisfied && upperBoundSatisfied;

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
  # Manual definition of callPackage which will set certain attributes for us within the package set.
  # Definition comes from the implementation of lib.customisation.makeScope:
  # https://github.com/NixOS/nixpkgs/blob/9f4fd5626d7aa9a376352fc244600c894b5a0c79/lib/customisation.nix#L608
  mkCudaPackagesCallPackage =
    finalCudaPackages:
    let
      inherit (finalCudaPackages) newScope;
      overrideAttrsFn = mkCudaPackagesOverrideAttrsDefaultsFn {
        inherit (finalCudaPackages) cudaNamePrefix;
        inherit (finalCudaPackages.pkgs)
          deduplicateRunpathEntriesHook
          ;
      };
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
    {
      cudaNamePrefix,
      deduplicateRunpathEntriesHook,
    }:
    let
      conditionallyAddHooks =
        prevAttrs: depListName:
        let
          prevDepList = prevAttrs.${depListName} or [ ];
        in
        prevDepList
        # We add a hook to deduplicate runpath entries.
        ++ optionals (!(elem deduplicateRunpathEntriesHook prevDepList)) [
          deduplicateRunpathEntriesHook
        ];
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

      nativeBuildInputs = conditionallyAddHooks prevAttrs "nativeBuildInputs";

      propagatedBuildInputs = conditionallyAddHooks prevAttrs "propagatedBuildInputs";
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
    (bimap (name: "Required package ${name} is missing") (const true))
  ];

  /**
    Replaces dots in a string with underscores.

    # Type

    ```
    dotsToUnderscores :: String -> String
    ```

    # Arguments

    str
    : The string for which dots shall be replaced by underscores

    # Example

    ```nix
    lib.cuda.utils.dotsToUnderscores "1.2.3"
    => "1_2_3"
    ```
  */
  dotsToUnderscores = replaceStrings [ "." ] [ "_" ];

  # TODO: Docs
  mkCudaPackagesVersionedName = cudaVersion: "cudaPackages_${dotsToUnderscores cudaVersion}";

  # TODO: Docs
  bimap = f: g: mapAttrs' (name: value: nameValuePair (f name) (g value));

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
