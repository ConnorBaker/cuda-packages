{ cudaLib, lib }:
let
  inherit (builtins) toString;
  inherit (cudaLib.types)
    attrs
    cudaCapability
    majorMinorVersion
    majorMinorPatchVersion
    nvccConfig
    redistBuilderArg
    redistBuilderArgs
    packageName
    redistSystem
    redistName
    version
    versionWithNumComponents
    ;
  inherit (cudaLib.utils) mkOptionsModule;
  inherit (lib.trivial) throwIf;
  inherit (lib.attrsets) attrNames;
  inherit (lib.lists) all;
  inherit (lib.types)
    addCheck
    anything
    attrsWith
    bool
    enum
    listOf
    nonEmptyListOf
    nonEmptyStr
    nullOr
    package
    path
    raw
    str
    strMatching
    submodule
    unspecified
    ;
in
# TODO(@connorbaker):
# Updating docs:
# - Type comes first
# - Arguments is now Inputs and follows Type
# - Input names should be in code blocks
# - Use `[]` instead of List
# - Give names to positional arguments
# - Examples should look like:
#     Examples
#     :::{.example}
#     ## `lib.attrsets.mapAttrsToList` usage example
#
#     ```nix
#     mapAttrsToList (name: value: name + value)
#         { x = "a"; y = "b"; }
#     => [ "xa" "yb" ]
#     ```
#
#     :::
{
  /**
    The option type of an attribute set with typed keys and values.

    # Type

    ```
    attrs :: (nameType :: OptionType) -> (valueType :: OptionType) -> OptionType
    ```

    # Inputs

    `nameType`

    : The option type of the names of the attribute set

    `valueType`

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
    The option type of information about a CUDA capability.

    # Type

    ```
    cudaCapabilityInfo :: OptionType
    ```
  */
  cudaCapabilityInfo =
    submodule (
      { name, ... }:
      mkOptionsModule {
        archName = {
          description = "The name of the microarchitecture.";
          type = nonEmptyStr;
        };
        cudaCapability = {
          description = "The CUDA capability.";
          type = cudaCapability;
          default = name;
        };
        dontDefaultAfterCudaMajorMinorVersion = {
          description = ''
            The CUDA version after which to exclude this capability from the list of default capabilities we build.

            The value `null` means we always include this capability in the default capabilities if it is supported.
          '';
          type = nullOr majorMinorVersion;
          default = null;
        };
        isAccelerated = {
          description = ''
            Whether this capability is an accelerated version of a base architecture.
            This field is notable because it tells us what architecture to build for (as accelerated architectures are
            not forward or backward compatible with the base architecture).
          '';
          type = bool;
          default = false;
        };
        isJetson = {
          description = ''
            Whether this capability is part of NVIDIA's line of Jetson embedded computers. This field is notable
            because it tells us what architecture to build for (as Jetson devices are aarch64).
            More on Jetson devices here: https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/
            NOTE: These architectures are only built upon request.
          '';
          type = bool;
          default = false;
        };
        maxCudaMajorMinorVersion = {
          description = ''
            The maximum (exclusive) CUDA version that supports this capability. `null` means there is no maximum.
          '';
          type = nullOr majorMinorVersion;
          default = null;
        };
        minCudaMajorMinorVersion = {
          description = "The minimum (inclusive) CUDA version that supports this capability.";
          type = majorMinorVersion;
        };
      }
    )
    // {
      name = "cudaCapabilityInfo";
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
    The option type of a redistributable system name.

    # Type

    ```
    redistSystem :: OptionType
    ```
  */
  redistSystem = enum cudaLib.data.redistSystems // {
    name = "redistSystem";
  };

  # TODO(@connorbaker): Docs
  redistBuilderArg =
    submodule (mkOptionsModule {
      redistName = {
        description = "The name of the redistributable to which this package belongs";
        type = redistName;
      };
      packageName = {
        description = "The name of the package";
        type = packageName;
      };
      fixupFn = {
        description = "An expression to be callPackage'd and then provided to overrideAttrs";
        type = raw;
        default = null;
      };
    })
    // {
      name = "redistBuilderArg";
    };

  redistBuilderArgs = attrs packageName redistBuilderArg // {
    name = "redistBuilderArgs";
  };

  /**
    The option type of a redistributable name.

    # Type

    ```
    redistName :: OptionType
    ```
  */
  redistName = enum cudaLib.data.redistNames // {
    name = "redistName";
  };

  /**
    The option type of an attribute set mapping redistributable names to fixup functions.

    # Type

    ```
    fixups :: OptionType
    ```
  */
  fixups = attrs redistName (attrs packageName raw) // {
    name = "fixups";
  };

  /**
    The option type of a CUDA capability.

    # Type

    ```
    cudaCapability :: OptionType
    ```
  */
  cudaCapability = strMatching "^[[:digit:]]+\\.[[:digit:]]+[a-z]?$" // {
    name = "cudaCapability";
  };

  /**
    The option type of a configuration for NVCC.

    # Type

    ```
    nvccConfig :: OptionType
    ```
  */
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

  /**
    The option type of a CUDA package set configuration.

    # Type

    ```
    cudaPackagesConfig :: OptionType
    ```
  */
  cudaPackagesConfig =
    submodule (mkOptionsModule {
      # NOTE: assertions vendored from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/assertions.nix
      assertions = {
        type = listOf unspecified;
        internal = true;
        default = [ ];
        example = [
          {
            assertion = false;
            message = "you can't enable this for that reason";
          }
        ];
        description = ''
          This option allows the cudaPackages module to express conditions that must hold for the evaluation of the
          package set to succeed, along with associated error messages for the user.
        '';
      };
      # NOTE: warnings vendored from https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/assertions.nix
      warnings = {
        internal = true;
        default = [ ];
        type = listOf str;
        example = [ "This package set is marked for removal" ];
        description = ''
          This option allows the cudaPackages module to show warnings to users during the evaluation of the package set
          configuration.
        '';
      };
      cudaCapabilities = {
        description = ''
          The CUDA capabilities to target.
          If empty, uses the default set of capabilities determined per-package set.
        '';
        type = listOf cudaCapability;
      };
      supportedCudaCapabilities = {
        description = ''
          The CUDA capabilities supported by the package set.
        '';
        type = listOf cudaCapability;
      };
      defaultCudaCapabilities = {
        description = ''
          The CUDA capabilities enabled by default for the package set.
        '';
        type = listOf cudaCapability;
      };
      cudaForwardCompat = {
        description = ''
          Whether to build with forward compatability enabled.
        '';
        type = bool;
      };
      cudaMajorMinorPatchVersion = {
        description = ''
          The version of CUDA provided by the package set.
        '';
        type = majorMinorPatchVersion;
      };
      hasAcceleratedCudaCapability = {
        description = ''
          Whether `cudaCapabilities` contains an accelerated CUDA capability.
        '';
        type = bool;
      };
      hasJetsonCudaCapability = {
        description = ''
          Whether `cudaCapabilities` contains a Jetson CUDA capability.
        '';
        type = bool;
      };
      hostRedistSystem = {
        description = ''
          The redistributable system of the host platform, to be used for redistributable packages.
        '';
        type = redistSystem;
      };
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
      redistBuilderArgs = {
        description = ''
          A flattened collection of redistBuilderArgs from all redists configured for this instance of the package set.
        '';
        type = redistBuilderArgs;
      };
    })
    // {
      name = "cudaPackagesConfig";
    };

  /**
    The option type of a version with a single component.

    # Type

    ```
    majorVersion :: OptionType
    ```
  */
  majorVersion = versionWithNumComponents 1 // {
    name = "majorVersion";
  };

  /**
    The option type of a version with two components.

    # Type

    ```
    majorMinorVersion :: OptionType
    ```
  */
  majorMinorVersion = versionWithNumComponents 2 // {
    name = "majorMinorVersion";
  };

  /**
    The option type of a version with three components.

    # Type

    ```
    majorMinorPatchVersion :: OptionType
    ```
  */
  majorMinorPatchVersion = versionWithNumComponents 3 // {
    name = "majorMinorPatchVersion";
  };

  /**
    The option type of a SHA-256, base64-encoded hash.

    # Type

    ```
    sriHash :: OptionType
    ```
  */
  sha256 = strMatching "^[[:alnum:]+/]{64}$" // {
    name = "sha256";
  };

  /**
    The option type of a Subresource Integrity hash.

    NOTE: The length of the hash is not checked!

    # Type

    ```
    sriHash :: OptionType
    ```
  */
  sriHash = strMatching "^(md5|sha(1|256|512))-([[:alnum:]+/]+={0,2})$" // {
    name = "sriHash";
  };

  /**
    The option type of a version with at least one component.

    # Type

    ```
    version :: OptionType
    ```
  */
  version = strMatching "^[[:digit:]]+(\.[[:digit:]]+)*$" // {
    name = "version";
  };

  /**
    The option type of a version with a fixed number of components.

    # Type

    ```
    versionWithNumComponents :: (numComponents :: Integer) -> OptionType
    ```

    # Inputs

    `numComponents`

    : The number of components in the version
  */
  versionWithNumComponents =
    numComponents:
    throwIf (numComponents < 1) "numComponents must be positive" (
      strMatching "^[[:digit:]]+(\.[[:digit:]]+){${toString (numComponents - 1)}}$"
    );
}
