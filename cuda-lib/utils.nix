{ cudaLib, lib }:
let
  inherit (builtins)
    deepSeq
    genericClosure
    getContext
    match
    pathExists
    readDir
    removeAttrs
    substring
    tryEval
    typeOf
    unsafeDiscardStringContext
    ;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets)
    attrNames
    attrValues
    catAttrs
    filterAttrs
    foldlAttrs
    genAttrs
    getAttr
    getAttrFromPath
    hasAttr
    isAttrs
    isDerivation
    listToAttrs
    mapAttrs
    mapAttrs'
    nameValuePair
    optionalAttrs
    showAttrPath
    ;
  inherit (cudaLib.data) redistUrlPrefix;
  inherit (cudaLib.types) redistName version;
  inherit (cudaLib.utils)
    attrPaths
    bimap
    dotsToUnderscores
    dropDots
    drvAttrPathsStrategy
    drvAttrPathsStrategyImpl
    flattenAttrs
    getNixSystems
    mkCmakeCudaArchitecturesString
    mkCudaPackagesCallPackage
    mkCudaPackagesOverrideAttrsDefaultsFn
    mkCudaPackagesScope
    mkCudaVariant
    mkGencodeFlag
    mkOptions
    mkRealArchitecture
    mkRedistConfig
    mkRedistUrl
    mkRedistUrlRelativePath
    mkVersionedManifests
    mkVersionedOverrides
    mkVirtualArchitecture
    packageExprPathsFromDirectoryRecursive
    packagesFromDirectoryRecursive'
    readDirIfExists
    trimComponents
    ;
  inherit (lib.debug) traceIf;
  inherit (lib.filesystem) packagesFromDirectoryRecursive;
  inherit (lib.fixedPoints) extends makeExtensible;
  inherit (lib.lists)
    concatMap
    elem
    filter
    findFirst
    head
    last
    map
    naturalSort
    optionals
    reverseList
    take
    unique
    ;
  inherit (lib.modules) mkDefault mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.strings)
    concatMapStringsSep
    concatStringsSep
    hasPrefix
    hasSuffix
    removePrefix
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
  inherit (lib.versions) major majorMinor splitVersion;
in
{
  # TODO: DOCS
  collectPackageConfigsForCudaVersion =
    cudaConfig: cudaMajorMinorPatchVersion:
    let
      inherit (cudaPackagesConfig) hostRedistSystem;
      cudaPackagesConfig = cudaConfig.cudaPackages.${cudaMajorMinorPatchVersion};
      backupCudaVariant = mkCudaVariant cudaMajorMinorPatchVersion;
      # Get the redist names and versions for our particular package set.
      redistNameToRedistVersion = cudaPackagesConfig.redists;
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
          redistSystem:
          let
            packageVariants = packages.${redistSystem};
            # Always show preference to the "source", then "linux-all" redistSystem if they are available, as they are
            # the most general.
            nixSystemIsSupported =
              redistSystem == "source"
              || redistSystem == "linux-all"
              || (
                redistSystem == hostRedistSystem && !hasAttr "source" packages && !hasAttr "linux-all" packages
              );
          in
          map (
            cudaVariant:
            let
              # Always show preference to the "None" cudaVariant if it is available, as it is the most general.
              packageInfo = packageVariants.${cudaVariant};
              cudaVariantIsSupported =
                cudaVariant == "None" || (cudaVariant == backupCudaVariant && !hasAttr "None" packageVariants);
            in
            # If the package variant is supported for this CUDA version, include information about it --
            # it means the package is available for *some* system.
            {
              ${packageName} = mkIf cudaVariantIsSupported {
                inherit redistName releaseInfo;
                # Attribute set handles deduplication for us; we use this to create platforms in meta.
                supportedNixSystemAttrs = genAttrs (getNixSystems redistSystem) (const null);
                supportedRedistSystemAttrs.${redistSystem} = null;
                # We want packageInfo to be default here so it can be successfully replaced by the chosen
                # package variant, if it exists.
                packageInfo = if nixSystemIsSupported then packageInfo else mkDefault packageInfo;
                callPackageOverrider = mkIf nixSystemIsSupported (
                  redistCallPackageOverriders.${packageName} or null
                );
                srcArgs = mkIf nixSystemIsSupported {
                  url = mkRedistUrl redistName (mkRedistUrlRelativePath {
                    inherit
                      cudaVariant
                      packageName
                      redistSystem
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
         , redistSystem :: RedistSystem
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

    redistSystem
    : The redist system of the package

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
      redistSystem,
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
        redistSystem
        (concatStringsSep "-" [
          packageName
          redistSystem
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
    cudaLib.utils.getLibPath "11.0" null
    => null
    ```

    ```nix
    cudaLib.utils.getLibPath "11.0" [ "10.2" "11" "11.0" "12" ]
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
    Maps a NVIDIA redistributable system to Nix systems.

    NOTE: This function returns a list of systems because the redistributable systems `"linux-all"` and
    `"source"` can be built on multiple systems.

    NOTE: This function *will* be called by unsupported systems because `cudaPackages` is part of
    `all-packages.nix`, which is evaluated on all systems. As such, we need to handle unsupported
    systems gracefully.

    # Example

    ```nix
    cudaLib.utils.getNixSystems "linux-sbsa"
    => [ "aarch64-linux" ]
    ```

    ```nix
    cudaLib.utils.getNixSystems "linux-aarch64"
    => [ "aarch64-linux" ]
    ```

    # Type

    ```
    getNixSystems :: RedistSystem -> List String
    ```

    # Arguments

    redistSystem
    : The NVIDIA redistributable system
  */
  getNixSystems =
    redistSystem:
    if redistSystem == "linux-x86_64" then
      [ "x86_64-linux" ]
    else if redistSystem == "linux-sbsa" || redistSystem == "linux-aarch64" then
      [ "aarch64-linux" ]
    else if redistSystem == "linux-all" || redistSystem == "source" then
      [
        "aarch64-linux"
        "x86_64-linux"
      ]
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
    cudaLib.utils.getRedistSystem true "aarch64-linux"
    => "linux-aarch64"
    ```

    ```nix
    cudaLib.utils.getRedistSystem false "aarch64-linux"
    => "linux-sbsa"
    ```

    # Type

    ```
    getRedistSystem :: Bool -> String -> String
    ```

    # Arguments

    hasJetsonCudaCapability
    : If configured for a Jetson device

    nixSystem
    : The Nix system
  */
  getRedistSystem =
    hasJetsonCudaCapability: nixSystem:
    if nixSystem == "x86_64-linux" then
      "linux-x86_64"
    else if nixSystem == "aarch64-linux" then
      if hasJetsonCudaCapability then "linux-aarch64" else "linux-sbsa"
    else
      "unsupported";

  /**
    TODO:
  */
  getSupportedRedistSystems =
    packages: desiredCudaVariant:
    filter (
      redistSystem:
      let
        packageVariants = packages.${redistSystem};
      in
      hasAttr "None" packageVariants || hasAttr desiredCudaVariant packageVariants
    ) (attrNames packages);

  /**
    Returns whether a capability should be built by default for a particular CUDA version.

    # Type

    ```
    cudaCapabilityIsDefault :: Version -> CudaCapabilityInfo -> Bool
    ```
  */
  cudaCapabilityIsDefault =
    cudaMajorMinorVersion:
    {
      dontDefaultAfterCudaMajorMinorVersion,
      isAccelerated,
      isJetson,
      ...
    }:
    let
      recentCapability =
        dontDefaultAfterCudaMajorMinorVersion == null
        || versionAtLeast dontDefaultAfterCudaMajorMinorVersion cudaMajorMinorVersion;
    in
    recentCapability && !isJetson && !isAccelerated;

  /**
    Returns whether a capability is supported for a particular CUDA version.

    # Type

    ```
    cudaCapabilityIsSupported :: Version -> CudaCapabilityInfo -> Bool
    ```
  */
  cudaCapabilityIsSupported =
    cudaMajorMinorVersion:
    { minCudaMajorMinorVersion, maxCudaMajorMinorVersion, ... }:
    let
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
    cudaLib.utils.mkCudaVariant "11.0"
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
      inherit (cudaLib.utils) mkMissingPackagesBadPlatformsConditions;
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
    cudaLib.utils.dotsToUnderscores "1.2.3"
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
    archPrefix: cudaCapability:
    let
      cap = dropDots cudaCapability;
    in
    "-gencode=arch=compute_${cap},code=${archPrefix}_${cap}";
  mkRealArchitecture = cudaCapability: "sm_" + dropDots cudaCapability;
  mkVirtualArchitecture = cudaCapability: "compute_" + dropDots cudaCapability;

  # TODO: Document.
  addNameToFetchFromGitLikeArgs =
    fetcher:
    let
      fetcherSupportsTagArg = fetcher.__functionArgs ? tag;
    in
    args:
    if args ? name then
      # Use `name` when provided.
      args
    else
      let
        inherit (args) owner repo rev;
        hasTagArg = args ? tag;
        revStrippedRefsTags = removePrefix "refs/tags/" rev;
        tagInRev = revStrippedRefsTags != rev;
        isHash = match "^[0-9a-f]{40}$" rev == [ ];
        shortHash = substring 0 8 rev;

        # If the fetcher doesn't support a `tag` argument, remove it and populate rev.
        supportOldTaglessArgs =
          if (!fetcherSupportsTagArg && hasTagArg) then
            removeAttrs args [ "tag" ]
            // optionalAttrs (!fetcherSupportsTagArg && hasTagArg) {
              rev =
                # Exactly one of tag or rev must be supplied.
                assert args.rev or null == null;
                "refs/tags/${args.tag}";
            }
          else
            args;
      in
      supportOldTaglessArgs
      // {
        name = concatStringsSep "-" [
          owner
          repo
          (
            # If tag is present that takes precedence.
            if args.tag or null != null then
              args.tag
            # If there's no tag, then rev *must* exist.
            else if tagInRev then
              revStrippedRefsTags
            else if isHash then
              shortHash
            else
              throw "Expected either a tag or a hash for the revision"
          )
        ];
      };

  /**
    A total version of `readDir` which returns an empty attribute set if the directory does not exist.

    # Type

    ```
    readDirIfExists :: Path -> AttrSet
    ```

    # Arguments

    path
    : A path to a directory

    # Returns

    An attribute set containing the contents of the directory mapped to file type if it exists, otherwise an empty
    attribute set.

    # Example

    Assume the directory `./foo` exists and contains the files `bar` and `baz`.

    ```nix
    cudaLib.utils.readDirIfExists ./foo
    => { bar = "regular"; baz = "regular"; }
    ```

    Assume the directory `./oops` does not exist.

    ```nix
    cudaLib.utils.readDirIfExists ./oops
    => { }
    ```
  */
  readDirIfExists = path: optionalAttrs (pathExists path) (readDir path);

  /**
    Removes the dots from a string.

    # Type

    ```
    dropDots :: String -> String
    ```

    # Arguments

    str
    : The string to remove dots from

    # Example

    ```nix
    cudaLib.utils.dropDots "1.2.3"
    => "123"
    ```
  */
  dropDots = replaceStrings [ "." ] [ "" ];

  /**
    Extracts the major, minor, and patch version from a string.

    # Example

    ```nix
    cudaLib.utils.majorMinorPatch "11.0.3.4"
    => "11.0.3"
    ```

    # Type

    ```
    majorMinorPatch :: String -> String
    ```

    # Arguments

    version
    : The version string
  */
  majorMinorPatch = trimComponents 3;

  /**
    Get a version string with no more than than the specified number of components.

    # Type

    ```
    trimComponents :: Integer -> String -> String
    ```

    # Arguments

    n
    : A positive integer corresponding to the maximum number of components to keep

    v
    : A version string

    # Example

    ```nix
    cudaLib.utils.trimComponents 1 "1.2.3.4"
    => "1"
    ```

    ```nix
    cudaLib.utils.trimComponents 3 "1.2.3.4"
    => "1.2.3"
    ```

    ```nix
    cudaLib.utils.trimComponents 9 "1.2.3.4"
    => "1.2.3.4"
    ```
  */
  trimComponents =
    n: v:
    pipe v [
      splitVersion
      (take n)
      (concatStringsSep ".")
    ];

  /**
    Produces a list of attribute paths for a given attribute set.

    # Type

    ```
    attrPaths :: { includeCond :: List String -> Any -> Bool
                 , recurseCond :: List String -> Any -> Bool
                 , trace :: ?Bool = false
                 }
              -> AttrSet
              -> List (List String)
    ```

    # Arguments

    includeCond
    : A function that takes an attribute path and a value and returns a boolean, controlling whether the attribute
    path should be included in the output.

    recurseCond
    : A function that takes an attribute path and a value and returns a boolean, controlling whether the attribute
    path should be recursed into.

    attrs
    : The attribute set to generate attribute paths for.
  */
  attrPaths =
    {
      includeCond,
      recurseCond,
      trace ? false,
    }:
    let
      maybeTrace = traceIf trace;
      go =
        parentAttrPath: parentAttrs:
        concatMap (
          name:
          let
            attrPath = parentAttrPath ++ [ name ];
            value = getAttr name parentAttrs;
            include = includeCond attrPath value;
            recurse = recurseCond attrPath value;
          in
          (
            if include then
              maybeTrace "lib.attrsets.attrPaths: including attribute ${showAttrPath attrPath}" [ attrPath ]
            else
              maybeTrace "lib.attrsets.attrPaths: excluding attribute ${showAttrPath attrPath}" [ ]
          )
          ++ (
            if recurse then
              maybeTrace "lib.attrsets.attrPaths: recursing into attribute ${showAttrPath attrPath}" (
                go attrPath value
              )
            else
              maybeTrace "lib.attrsets.attrPaths: not recursing into attribute ${showAttrPath attrPath}" [ ]
          )
        ) (attrNames parentAttrs);
    in
    attrs:
    assert assertMsg (isAttrs attrs) "lib.attrsets.attrPaths: `attrs` must be an attribute set";
    go [ ] attrs;

  # Credit for this strategy goes to Adam Joseph and is taken from their work on
  # https://github.com/NixOS/nixpkgs/pull/269356.
  drvAttrPathsStrategyImpl = makeExtensible (final: {
    # No release package attrpath may have any of these attrnames as
    # its initial component.
    #
    # If you can find a way to remove any of these entries without
    # causing CI to fail, please do so.
    #
    excludeAtTopLevel = {
      AAAAAASomeThingsFailToEvaluate = null;

      #  spliced packagesets
      __splicedPackages = null;
      pkgsBuildBuild = null;
      pkgsBuildHost = null;
      pkgsBuildTarget = null;
      pkgsHostHost = null;
      pkgsHostTarget = null;
      pkgsTargetTarget = null;
      buildPackages = null;
      targetPackages = null;

      # cross packagesets
      pkgsLLVM = null;
      pkgsMusl = null;
      pkgsStatic = null;
      pkgsCross = null;
      pkgsx86_64Darwin = null;
      pkgsi686Linux = null;
      pkgsLinux = null;
      pkgsExtraHardening = null;
    };

    # No release package attrname may have any of these at a component
    # anywhere in its attrpath.  These are the names of gigantic
    # top-level attrsets that have leaked into so many sub-packagesets
    # that it's easier to simply exclude them entirely.
    #
    # If you can find a way to remove any of these entries without
    # causing CI to fail, please do so.
    #
    excludeAtAnyLevel = {
      lib = null;
      override = null;
      __functor = null;
      __functionArgs = null;
      __splicedPackages = null;
      newScope = null;
      scope = null;
      pkgs = null;
      callPackage = null;
      mkDerivation = null;
      overrideDerivation = null;
      overrideScope = null;
      overrideScope' = null;

      # Special case: lib/types.nix leaks into a lot of nixos-related
      # derivations, and does not eval deeply.
      type = null;
    };

    isExcluded =
      attrPath:
      hasAttr (head attrPath) final.excludeAtTopLevel || hasAttr (last attrPath) final.excludeAtAnyLevel;

    # Include the attribute so long as it has a non-null drvPath.
    # NOTE: We must wrap with `tryEval` and `deepSeq` to catch values which are just `throw`s.
    # NOTE: Do not use `meta.available` because it does not (by default) recursively check dependencies, and requires
    # an undocumented config option (checkMetaRecursively) to do so:
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/check-meta.nix#L496
    # The best we can do is try to compute the drvPath and see if it throws.
    # What we really need is something like:
    # https://github.com/NixOS/nixpkgs/pull/245322
    includeCond =
      attrPath: value:
      let
        unsafeTest = isDerivation value && value.drvPath or null != null;
        attempt = tryEval (deepSeq unsafeTest unsafeTest);
      in
      !(final.isExcluded attrPath) && attempt.success && attempt.value;

    # Recurse when recurseForDerivations is not set.
    recurseByDefault = false;

    # Recurse so long as the attribute set:
    # - is not a derivation or set __recurseIntoDerivationForReleaseJobs set to true
    # - set recurseForDerivations to true or recurseForDerivations is not set and recurseByDefault is true
    # - does not set __attrsFailEvaluation to true
    # NOTE: We must wrap with `tryEval` and `deepSeq` to catch values which are just `throw`s.
    recurseCond =
      attrPath: value:
      let
        unsafeTest =
          isAttrs value
          && (!(isDerivation value) || value.__recurseIntoDerivationForReleaseJobs or false)
          && value.recurseForDerivations or final.recurseByDefault
          && !(value.__attrsFailEvaluation or false);
        attempt = tryEval (deepSeq unsafeTest unsafeTest);
      in
      !(final.isExcluded attrPath) && attempt.success && attempt.value;
  });

  drvAttrPathsStrategy = {
    inherit (drvAttrPathsStrategyImpl) includeCond recurseCond;
  };

  drvAttrPathsRecurseByDefaultStrategy = {
    inherit (drvAttrPathsStrategyImpl.extend (_: _: { recurseByDefault = true; }))
      includeCond
      recurseCond
      ;
  };

  /**
    TODO: Work on docs.

    # Type

    ```
    flattenAttrs :: { includeCond :: List String -> Any -> Bool
                    , recurseCond :: List String -> Any -> Bool
                    , trace :: ?Bool = false
                    }
                 -> AttrSet
                 -> AttrSet
    ```
  */
  flattenAttrs =
    strategy: attrs:
    pipe attrs [
      (attrPaths strategy)
      (map (attrPath: nameValuePair (showAttrPath attrPath) (getAttrFromPath attrPath attrs)))
      listToAttrs
    ];

  /**
    TODO: Work on docs.

    # Type

    ```
    flattenDrvTree :: AttrSet -> AttrSet
    ```
  */
  flattenDrvTree = flattenAttrs drvAttrPathsStrategy;

  # TODO: Docs
  collectDepsRecursive =
    let
      mkItem = dep: {
        # String interpolation is easier than dep.outPath with a fallback to "${dep}" in the case of a path or string with context.
        key = unsafeDiscardStringContext "${dep}";
        inherit dep;
      };

      # listStrategy :: List Any -> List (Derivation | Path)
      listStrategy = concatMap getDepsFromValueSingleStep;
      # Attribute names can't be paths or strings with context.
      # setStrategy :: Attrs Any -> List (Derivation | Path)
      setStrategy = attrs: if isDerivation attrs then [ attrs ] else listStrategy (attrValues attrs);
      # stringStrategy :: String -> List Path
      stringStrategy = string: attrNames (getContext string);
      # pathStrategy :: Path -> List Path
      pathStrategy = path: [ path ];
      # fallbackStrategy :: a -> List (Derivation | Path)
      fallbackStrategy = const [ ];

      strategies = {
        list = listStrategy;
        set = setStrategy;
        string = stringStrategy;
        path = pathStrategy;
      };

      # getDrvsFromValueSingleStep :: a -> List (Derivation | Path)
      # type :: "int" | "bool" | "string" | "path" | "null" | "set" | "list" | "lambda" | "float"
      getDepsFromValueSingleStep = value: (strategies.${typeOf value} or fallbackStrategy) value;
    in
    drvs:
    catAttrs "dep" (genericClosure {
      startSet = map mkItem drvs;
      # If we don't have drvAttrs then it's not a derivation produced by mkDerivation and we can just return
      # since there's no further processing we can do.
      # NOTE: Processing drvAttrs is safer than trying to process the attribute set resulting from mkDerivation.
      operator =
        item:
        if item.dep ? drvAttrs then map mkItem (getDepsFromValueSingleStep item.dep.drvAttrs) else [ ];
    });

  # TODO: Copy these docs to the module system.

  # Flags are determined based on your CUDA toolkit by default.  You may benefit
  # from improved performance, reduced file size, or greater hardware support by
  # passing a configuration based on your specific GPU environment.
  #
  # cudaCapabilities :: List Capability
  # List of hardware generations to build.
  # E.g. [ "8.0" ]
  # Currently, the last item is considered the optional forward-compatibility arch,
  # but this may change in the future.
  #
  # cudaForwardCompat :: Bool
  # Whether to include the forward compatibility gencode (+PTX)
  # to support future GPU generations.
  # E.g. true
  #
  # Please see the accompanying documentation or https://github.com/NixOS/nixpkgs/pull/205351

  formatCapabilities =
    {
      cudaCapabilityToInfo,
      cudaCapabilities,
      cudaForwardCompat ? true,
    }:
    let
      # realArchs :: List String
      # The real architectures are physical architectures supported by the CUDA version.
      # E.g. [ "sm_75" "sm_86" ]
      realArchs = map mkRealArchitecture cudaCapabilities;

      # virtualArchs :: List String
      # The virtual architectures are typically used for forward compatibility, when trying to support
      # an architecture newer than the CUDA version allows.
      # E.g. [ "compute_75" "compute_86" ]
      virtualArchs = map mkVirtualArchitecture cudaCapabilities;

      # gencode :: List String
      # A list of CUDA gencode arguments to pass to NVCC.
      # E.g. [ "-gencode=arch=compute_75,code=sm_75" ... "-gencode=arch=compute_86,code=compute_86" ]
      gencode =
        let
          base = map (mkGencodeFlag "sm") cudaCapabilities;
          forward = mkGencodeFlag "compute" (last cudaCapabilities);
        in
        base ++ optionals cudaForwardCompat [ forward ];
    in
    {
      inherit
        cudaCapabilities
        cudaForwardCompat
        gencode
        realArchs
        virtualArchs
        ;

      # archNames :: List String
      # E.g. [ "Ampere" "Turing" ]
      archNames = pipe cudaCapabilities [
        (map (cudaCapability: cudaCapabilityToInfo.${cudaCapability}.archName))
        unique
        naturalSort
      ];

      # archs :: List String
      # By default, build for all supported architectures and forward compatibility via a virtual
      # architecture for the newest supported architecture.
      # E.g. [ "sm_75" "sm_86" "compute_86" ]
      archs = realArchs ++ optionals cudaForwardCompat [ (last virtualArchs) ];

      # gencodeString :: String
      # A space-separated string of CUDA gencode arguments to pass to NVCC.
      # E.g. "-gencode=arch=compute_75,code=sm_75 ... -gencode=arch=compute_86,code=compute_86"
      gencodeString = concatStringsSep " " gencode;

      # cmakeCudaArchitecturesString :: String
      # A semicolon-separated string of CUDA capabilities without dots, suitable for passing to CMake.
      # E.g. "75;86"
      cmakeCudaArchitecturesString = mkCmakeCudaArchitecturesString cudaCapabilities;
    };
}
