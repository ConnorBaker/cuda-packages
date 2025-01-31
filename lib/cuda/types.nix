{ lib }:
let
  inherit (lib.cuda.types)
    attrs
    cudaCapability
    cudaVariant
    features
    manifest
    nvccConfig
    packageInfo
    packageName
    packages
    packageVariants
    redistArch
    redistConfig
    redistName
    release
    releaseInfo
    sriHash
    version
    versionedManifests
    versionedOverrides
    ;
  inherit (lib.cuda.utils) mkOptionsModule;
  inherit (lib.attrsets) attrNames;
  inherit (lib.lists) all;
  inherit (lib.upstreamable.types) majorMinorVersion;
  inherit (lib.types)
    addCheck
    attrsWith
    bool
    enum
    functionTo
    lazyAttrsOf
    listOf
    nonEmptyListOf
    nonEmptyStr
    nullOr
    oneOf
    package
    path
    raw
    strMatching
    submodule
    ;
in
{
  inherit (lib.upstreamable.types)
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
  features =
    submodule (mkOptionsModule {
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
    })
    // {
      name = "features";
    };

  /**
    The option type of information about a GPU.

    # Type

    ```
    gpuInfo :: OptionType
    ```
  */
  gpuInfo =
    submodule (
      { name, ... }:
      mkOptionsModule {
        archName = {
          description = "The name of the microarchitecture.";
          type = nonEmptyStr;
        };
        cudaCapability = {
          description = "The CUDA capability of the GPU.";
          type = cudaCapability;
          default = name;
        };
        dontDefaultAfterCudaMajorMinorVersion = {
          description = ''
            The CUDA version after which to exclude this GPU from the list of default capabilities we build.

            The value `null` means we always include this GPU in the default capabilities if it is supported.
          '';
          type = nullOr majorMinorVersion;
        };
        isJetson = {
          description = ''
            Whether a GPU is part of NVIDIA's line of Jetson embedded computers. This field is notable because it tells us
            what architecture to build for (as Jetson devices are aarch64).
            More on Jetson devices here: https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/
            NOTE: These architectures are only built upon request.
          '';
          type = bool;
        };
        maxCudaMajorMinorVersion = {
          description = ''
            The maximum (exclusive) CUDA version that supports this GPU. `null` means there is no maximum.
          '';
          type = nullOr majorMinorVersion;
        };
        minCudaMajorMinorVersion = {
          description = "The minimum (inclusive) CUDA version that supports this GPU.";
          type = majorMinorVersion;
        };
      }
    )
    // {
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
  packageInfo =
    submodule (mkOptionsModule {
      features = {
        description = "Features the package provides";
        type = features;
      };
      recursiveHash = {
        description = "Recursive NAR hash of the unpacked tarball";
        type = sriHash;
      };
      relativePath = {
        description = "The path to the package in the redistributable tree or null if it can be reconstructed.";
        type = nullOr nonEmptyStr;
        default = null;
      };
    })
    // {
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
  redistConfig =
    submodule (mkOptionsModule {
      versionedOverrides = {
        description = ''
          Overrides for packages provided by the redistributable.
        '';
        type = versionedOverrides;
      };
      versionedManifests = {
        description = ''
          Data required to produce packages for (potentially multiple) versions of CUDA.
        '';
        type = versionedManifests;
      };
    })
    // {
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
  releaseInfo =
    submodule (mkOptionsModule {
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
        type = version;
      };
    })
    // {
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

  nvccConfig =
    submodule (mkOptionsModule {
      hostStdenv = {
        description = ''
          The host stdenv compiler to use when building CUDA code.
          This option is used to determine the version of the host compiler to use when building CUDA code.
        '';
        default = null;
        type = nullOr package;
      };
    })
    // {
      name = "nvccConfig";
    };

  # TODO: Docs
  cudaPackagesConfig =
    submodule (mkOptionsModule {
      nvcc = {
        description = ''
          Configuration options for nvcc.
        '';
        type = nvccConfig;
        default = { };
      };
      packagesDirectories = {
        description = ''
          Paths to directories containing Nix expressions to add to the package set.

          Package names created from directories later in the list override packages earlier in the list.
        '';
        type = listOf path;
        default = [ ];
      };
      redists = {
        description = ''
          Maps redist name to version.

          Versions must match the format of the corresponding versioned manifest for the redist.

          If a redistributable is not present in this attribute set, it is not included in the package set.

          If the version specified for a redistributable is not present in the corresponding versioned manifest, it is not included in the package set.
        '';
        type = attrs redistName version;
        default = { };
      };
    })
    // {
      name = "cudaPackagesConfig";
    };
}
