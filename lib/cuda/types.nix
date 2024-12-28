{ lib }:
let
  inherit (lib.cuda.types)
    attrs
    cudaVariant
    manifest
    packageInfo
    packageName
    packages
    packageVariants
    redistArch
    redistConfig
    redistName
    release
    releaseInfo
    version
    ;
  inherit (lib.cuda.utils) mkOptionsModule;
  inherit (lib.attrsets) attrNames;
  inherit (lib.lists) all;
  inherit (lib.modules) importApply;
  inherit (lib.types)
    addCheck
    attrsWith
    enum
    functionTo
    lazyAttrsOf
    oneOf
    raw
    strMatching
    submodule
    ;

  mkOptionsModuleIntoOptionType = path: submodule (importApply path { inherit lib; });
in
{
  inherit (lib.upstreamable.types)
    majorMinorPatchBuildVersion
    majorMinorPatchVersion
    majorMinorVersion
    majorVersion
    sha256
    sriHash
    version
    versionWithNumComponents
    ;

  /**
    The option type of an attribute set with typed keys and values.

    # Type

    ```
    attrs :: OptionType -> OptionType -> OptionType
    ```

    # Arguments

    nameType
    : The option type of the names of the attribute set

    valueType
    : The option type of the values of the attribute set
  */
  attrs =
    nameType: valueType:
    addCheck (attrsWith {
      elemType = valueType;
      lazy = false;
      placeholder = nameType.name;
    }) (attrs: all nameType.check (attrNames attrs));

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
  cudaVariant = strMatching "^(None|cuda[[:digit:]]+)$" // {
    name = "cudaVariant";
  };

  /**
    The option type of a real CUDA architecture.

    # Type

    ```
    cudaRealArch :: OptionType
    ```
  */
  cudaRealArch = strMatching "^sm_[[:digit:]]+[a-z]?$" // {
    name = "cudaRealArch";
  };

  /**
    The option type of a features attribute set.

    # Type

    ```
    features :: OptionType
    ```
  */
  features = mkOptionsModuleIntoOptionType ./modules/features.nix // {
    name = "features";
  };

  /**
    The option type of information about a GPU.

    # Type

    ```
    gpuInfo :: OptionType
    ```
  */
  gpuInfo = mkOptionsModuleIntoOptionType ./modules/gpu-info.nix // {
    name = "gpuInfo";
  };

  /**
    The option type of a manifest attribute set.

    # Type

    ```
    manifest :: OptionType
    ```
  */
  manifest = attrs packageName release // {
    name = "manifest";
  };

  /**
    The option type of a package info attribute set.

    # Type

    ```
    packageInfo :: OptionType
    ```
  */
  packageInfo = mkOptionsModuleIntoOptionType ./modules/package-info.nix // {
    name = "packageInfo";
  };

  /**
    The option type of a `packages` attribute set.

    # Type

    ```
    packages :: OptionType
    ```
  */
  packages = attrs redistArch packageVariants // {
    name = "packages";
  };

  /**
    The option type of a package name in a CUDA package set.

    # Type

    ```
    packageName :: OptionType
    ```
  */
  packageName = strMatching "^[[:alnum:]_-]+$" // {
    name = "packageName";
  };

  /**
    The option type of a package variant attribute set.

    # Type

    ```
    packageVariants :: OptionType
    ```
  */
  packageVariants = attrs cudaVariant packageInfo // {
    name = "packageVariants";
  };

  /**
    The option type of a redistributable architecture name.

    # Type

    ```
    redistArch :: OptionType
    ```
  */
  redistArch = enum lib.cuda.data.redistArches // {
    name = "redistArch";
  };

  /**
    The option type of an attribute set configuring the way in which a redistributable suite is made into packages.

    # Type

    ```
    redistName :: OptionType
    ```
  */
  redistConfig = mkOptionsModuleIntoOptionType ./modules/redist-config.nix // {
    name = "redistConfig";
  };

  /**
    The option type of a redistributable name.

    # Type

    ```
    redistName :: OptionType
    ```
  */
  redistName = enum lib.cuda.data.redistNames // {
    name = "redistName";
  };

  /**
    The option type of an attribute set mapping redistributable names to redistributable configurations.

    # Type

    ```
    redists :: OptionType
    ```
  */
  redists = attrs redistName redistConfig // {
    name = "redists";
  };

  /**
    The option type of a release attribute set.

    # Type

    ```
    release :: OptionType
    ```
  */
  release =
    submodule (mkOptionsModule {
      releaseInfo.type = releaseInfo;
      packages.type = packages;
    })
    // {
      name = "release";
    };

  /**
    The option type of a release info attribute set.

    # Type

    ```
    releaseInfo :: OptionType
    ```
  */
  releaseInfo = mkOptionsModuleIntoOptionType ./modules/release-info.nix // {
    name = "releaseInfo";
  };

  /**
    The option type of a versioned manifest attribute set.

    # Type

    ```
    versionedManifests :: OptionType
    ```
  */
  versionedManifests = attrs version manifest // {
    name = "versionedManifests";
  };

  /**
    The option type of a versioned override attribute set.

    # Type

    ```
    versionedOverrides :: OptionType
    ```
  */
  # NOTE: `raw` in our case is typically a path to a nix expression, but could be a callPackageOverrider
  versionedOverrides = attrs version (attrs packageName raw) // {
    name = "versionedOverrides";
  };

  # TODO: Better organize/alphabetize.

  /**
    The option type of a `callPackage` overrider.

    These are functions which are passed to callPackage, and then provided to overrideAttrs.

    NOTE: The argument provided to overrideAttrs MUST be a function -- if it is not, callPackage will set
    the override attribute on the resulting attribute set, which when provided to overrideAttrs will break
    the package evaluation.

    # Type

    ```
    callPackageOverrider :: OptionType
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
    ])
    // {
      name = "callPackageOverrider";
    };

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
  cudaCapability = strMatching "^[[:digit:]]+\\.[[:digit:]]+[a-z]?$" // {
    name = "cudaCapability";
  };

  # TODO: Docs
  nvccConfig = mkOptionsModuleIntoOptionType ./modules/nvcc-config.nix // {
    name = "nvccConfig";
  };

  # TODO: Docs
  cudaPackagesConfig = mkOptionsModuleIntoOptionType ./modules/cuda-packages-config.nix // {
    name = "cudaPackagesConfig";
  };
}
