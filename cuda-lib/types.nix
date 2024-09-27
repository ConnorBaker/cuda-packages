{ cuda-lib, lib }:
let
  inherit (cuda-lib.utils) mkOptions;
  inherit (lib.strings) concatStringsSep;
  inherit (lib.types)
    addCheck
    enum
    functionTo
    lazyAttrsOf
    nonEmptyListOf
    nonEmptyStr
    nullOr
    oneOf
    raw
    strMatching
    submodule
    ;
in
{
  /**
    The option type of an attribute set with typed keys and values.

    # Type

    ```
    attrs :: OptionType -> OptionType -> OptionType
    ```

    # Arguments

    keyType
    : The option type of the keys of the attribute set

    valueType
    : The option type of the values of the attribute set
  */
  # TODO: Look into how `pkgs` makes an option type by overriding another option type:
  # https://github.com/NixOS/nixpkgs/blob/a6cc776496975eaef2de3218505c85bb5059fccb/lib/types.nix#L524-L530
  # We should do that for `attrs` and `function` to make docs more readable.
  # TODO: Not able to look at the keys in aggregate -- each typing decision is made per-key.
  attrs =
    keyType: valueType:
    addCheck (lib.types.attrsOf valueType) (
      attrs: builtins.all keyType.check (builtins.attrNames attrs)
    );

  /**
    The option type of a CUDA variant.

    CUDA variants are used in NVIDIA's redistributable manifests to specify the version of CUDA that a package is
    compatible with. They are named `cudaX.Y` where `X` and `Y` are the major and minor versions of CUDA, respectively.

    As a by-product of the Python scripts which generate the manifests used to create the CUDA package sets, a special
    value of `"None"` is used to indicate that a package is not specific to any version of CUDA.

    # Type

    ```
    cudaVariant :: OptionType
    ```
  */
  cudaVariant = strMatching "^(None|cuda[[:digit:]]+)$";

  /**
    The option type of a features attribute set.

    # Type

    ```
    features :: OptionType
    ```
  */
  features = submodule {
    options = mkOptions {
      cudaVersionsInLib = {
        description = "Subdirectories of the `lib` directory which are named after CUDA versions";
        type = nullOr (nonEmptyListOf (strMatching "^[[:digit:]]+(\.[[:digit:]]+)?$"));
        default = null;
      };
      outputs = {
        description = ''
          The outputs provided by a package.

          A `bin` output requires that we have a non-empty `bin` directory containing at least one file with the
          executable bit set.

          A `dev` output requires that we have at least one of the following non-empty directories:

          - `lib/pkgconfig`
          - `share/pkgconfig`
          - `lib/cmake`
          - `share/aclocal`

          NOTE: Absent from this list is `include`, which is handled by the `include` output. This is because the `dev`
          output in Nixpkgs is used for development files and is selected as the default output to install if present.
          Since we want to be able to access only the header files, they are present in a separate output.

          A `doc` output requires that we have at least one of the following non-empty directories:

          - `share/info`
          - `share/doc`
          - `share/gtk-doc`
          - `share/devhelp`
          - `share/man`

          An `include` output requires that we have a non-empty `include` directory.

          A `lib` output requires that we have a non-empty lib directory containing at least one shared library.

          A `python` output requires that we have a non-empty `python` directory.

          A `sample` output requires that we have a non-empty `samples` directory.

          A `static` output requires that we have a non-empty lib directory containing at least one static library.

          A `stubs` output requires that we have a non-empty `lib/stubs` or `stubs` directory containing at least one
          shared or static library.
        '';
        type = nonEmptyListOf (enum [
          "out" # Always present
          "bin"
          "dev"
          "doc"
          "include"
          "lib"
          "python"
          "sample"
          "static"
          "stubs"
        ]);
      };
    };
  };

  /**
    The option type of a manifest attribute set.

    # Type

    ```
    manifest :: OptionType
    ```
  */
  manifest = cuda-lib.types.attrs cuda-lib.types.packageName cuda-lib.types.release;

  /**
    The option type of a package info attribute set.

    # Type

    ```
    packageInfo :: OptionType
    ```
  */
  packageInfo = submodule {
    options = mkOptions {
      features = {
        description = "Features the package provides";
        type = cuda-lib.types.features;
      };
      recursiveHash = {
        description = "Recursive NAR hash of the unpacked tarball";
        type = cuda-lib.types.sriHash;
      };
      relativePath = {
        description = "The path to the package in the redistributable tree or null if it can be reconstructed.";
        type = nullOr nonEmptyStr;
        default = null;
      };
    };
  };

  /**
    The option type of a `packages` attribute set.

    # Type

    ```
    packages :: OptionType
    ```
  */
  packages = cuda-lib.types.attrs cuda-lib.types.platform cuda-lib.types.packageVariants;

  /**
    The option type of a package name in a CUDA package set.

    # Type

    ```
    packageName :: OptionType
    ```
  */
  packageName = strMatching "^[[:alnum:]_-]+$";

  /**
    The option type of a package variant attribute set.

    # Type

    ```
    packageVariants :: OptionType
    ```
  */
  packageVariants = cuda-lib.types.attrs cuda-lib.types.cudaVariant cuda-lib.types.packageInfo;

  /**
    The option type of a platform.

    # Type

    ```
    platform :: OptionType
    ```
  */
  platform = enum cuda-lib.data.platforms;

  /**
    The option type of an attribute set configuring the way in which a redistributable suite is made into packages.

    # Type

    ```
    redistName :: OptionType
    ```
  */
  redistConfig = submodule {
    options = mkOptions {
      overrides = {
        description = ''
          Overrides for packages provided by the redistributable.

          NOTE: Trying to use a more expressive type than `raw` causes the automatic-argument detection we do to
          fail, as the `check` function for the type interferes with the functions in the `overrides` attribute
          set.
        '';
        type = cuda-lib.types.attrs cuda-lib.types.packageName raw;
      };
      versionedManifests = {
        description = ''
          Data required to produce packages for (potentially multiple) versions of CUDA.
        '';
        type = cuda-lib.types.versionedManifests;
      };
      versionPolicy = {
        description = ''
          Only the latest version matching the selected policy will be used. If a version has fewer parts than the
          selected policy, it will be treated as if it has the missing parts set to 0. For example, if the policy
          is "minor" and the latest version is "1.2", it will be treated as "1.2.0".
        '';
        type = enum [
          "major"
          "minor"
          "patch"
          "build"
        ];
        default = "minor";
      };
    };
  };

  /**
    The option type of a redistributable name.

    # Type

    ```
    redistName :: OptionType
    ```
  */
  redistName = enum cuda-lib.data.redistNames;

  /**
    The option type of a URL of for something in a redistributable's tree.

    # Type

    ```
    redistUrl :: OptionType
    ```
  */
  redistUrl =
    let
      redistNamePattern = "(${concatStringsSep "|" cuda-lib.data.redistNames})";
      redistUrlPrefixPattern = "(${cuda-lib.data.redistUrlPrefix})";
      redistUrlPattern = "${redistUrlPrefixPattern}/${redistNamePattern}/redist/(.+)";
    in
    strMatching redistUrlPattern;

  /**
    The option type of an attribute set mapping redistributable names to redistributable configurations.

    # Type

    ```
    redists :: OptionType
    ```
  */
  redists = cuda-lib.types.attrs cuda-lib.types.redistName cuda-lib.types.redistConfig;

  /**
    The option type of a release attribute set.

    # Type

    ```
    release :: OptionType
    ```
  */
  release = submodule {
    options = mkOptions {
      releaseInfo.type = cuda-lib.types.releaseInfo;
      packages.type = cuda-lib.types.packages;
    };
  };

  /**
    The option type of a release info attribute set.

    # Type

    ```
    releaseInfo :: OptionType
    ```
  */
  releaseInfo = submodule {
    options = mkOptions {
      licensePath = {
        description = "The path to the license file in the redistributable tree";
        type = nullOr nonEmptyStr;
        default = null;
      };
      license = {
        description = "The license of the redistributable";
        type = nullOr nonEmptyStr;
      };
      name = {
        description = "The full name of the redistributable";
        type = nullOr nonEmptyStr;
      };
      version = {
        description = "The version of the redistributable";
        type = cuda-lib.types.version;
      };
    };
  };

  /**
    The option type of a SHA-256, base64-encoded hash.

    # Type

    ```
    sriHash :: OptionType
    ```
  */
  sha256 = strMatching "^[[:alnum:]+/]{64}$";

  /**
    The option type of a Subresource Integrity hash.

    NOTE: The length of the hash is not checked!

    # Type

    ```
    sriHash :: OptionType
    ```
  */
  sriHash = strMatching "^(md5|sha(1|256|512))-([[:alnum:]+/]+={0,2})$";

  /**
    The option type of a version with at least one component.

    # Type

    ```
    version :: OptionType
    ```
  */
  version = strMatching "^[[:digit:]]+(\.[[:digit:]]+)*$";

  /**
    The option type of a versioned manifest attribute set.

    # Type

    ```
    versionedManifests :: OptionType
    ```
  */
  versionedManifests = cuda-lib.types.attrs cuda-lib.types.version cuda-lib.types.manifest;

  # TODO: Better organize/alphabetize.

  /**
    The option type of a `callPackage` overrider.

    These are functions which are passed to callPackage, and then provided to overrideAttrs.

    NOTE: The argument provided to overrideAttrs MUST be a function -- if it is not, callPackage will set
    the override attribute on the resulting attribute set, which when provided to overrideAttrs will break
    the package evaluation.

    # Type

    ```
    versionWithNumComponents :: OptionType
    ```
  */
  callPackageOverrider =
    let
      overrideAttrsPrevFn = functionTo (lazyAttrsOf raw);
      overrideAttrsFinalPrevFn = functionTo overrideAttrsPrevFn;
    in
    functionTo (oneOf [
      overrideAttrsPrevFn
      overrideAttrsFinalPrevFn
    ]);

  /**
    The option type of a CUDA capability.

    # Type

    ```
    cudaCapability :: OptionType
    ```
  */
  # TODO: Possible improvement for error messages?
  # error: attribute 'deprecationMessage' missing
  #    at /nix/store/djw90qs3g3awfpcd7rhx80017620nm07-source/lib/modules.nix:805:17:
  #       804|       warnDeprecation =
  #       805|         warnIf (opt.type.deprecationMessage != null)
  #          |                 ^
  #       806|           "The type `types.${opt.type.name}' of option `${showOption loc}' defined in ${showFiles opt.declarations} is deprecated. ${opt.type.deprecationMessage}";
  #
  # When we leave off mkOption on cudaCapability, we get that error. However, as `options.types` is defined as a submodule
  # of freeformType = optionType, it should instead provide an error message about how cudaCapability is not a valid option type.
  # NOTE: I can't think of a way to actually improve this error message, because we would need to do type-checking on the options attribute set,
  # not the config attribute set (which is where checks are performed).
  cudaCapability = strMatching "^[[:digit:]]+\\.[[:digit:]]+[a-z]?$";

  /**
    The option type of an element of a flattened `Redists`.

    # Type

    ```
    flattenedRedistsElem :: OptionType
    ```
  */
  flattenedRedistsElem = submodule {
    options = mkOptions {
      cudaVariant.type = cuda-lib.types.cudaVariant;
      packageInfo.type = cuda-lib.types.packageInfo;
      packageName.type = cuda-lib.types.packageName;
      platform.type = cuda-lib.types.platform;
      redistName.type = cuda-lib.types.redistName;
      releaseInfo.type = cuda-lib.types.releaseInfo;
      # NOTE: This is the version of the manifest, not the version of an individual redist package (that is
      # provided by releaseInfo.version).
      version.type = cuda-lib.types.version;
    };
  };

  /**
    The option type of a version with a single component.

    # Type

    ```
    majorVersion :: OptionType
    ```
  */
  majorVersion = cuda-lib.types.versionWithNumComponents 1;

  /**
    The option type of a version with two components.

    # Type

    ```
    majorMinorVersion :: OptionType
    ```
  */
  majorMinorVersion = cuda-lib.types.versionWithNumComponents 2;

  /**
    The option type of a version with three components.

    # Type

    ```
    majorMinorPatchVersion :: OptionType
    ```
  */
  majorMinorPatchVersion = cuda-lib.types.versionWithNumComponents 3;

  /**
    The option type of a version with four components.

    # Type

    ```
    majorMinorPatchBuildVersion :: OptionType
    ```
  */
  majorMinorPatchBuildVersion = cuda-lib.types.versionWithNumComponents 4;

  /**
    The option type of a version with a fixed number of components.

    # Type

    ```
    versionWithNumComponents :: Integer -> OptionType
    ```

    # Arguments

    numComponents
    : The number of components in the version
  */
  versionWithNumComponents =
    numComponents:
    if numComponents < 1 then
      throw "numComponents must be positive"
    else
      strMatching "^[[:digit:]]+(\.[[:digit:]]+){${toString (numComponents - 1)}}$";
}
