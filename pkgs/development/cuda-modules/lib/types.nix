{ cudaLib, lib }:
let
  inherit (builtins) toString;
  inherit (cudaLib.types)
    cudaCapability
    majorMinorVersion
    versionWithNumComponents
    ;
  inherit (cudaLib.utils) mkOptionsModule;
  inherit (lib.trivial) throwIf;
  inherit (lib.attrsets) attrNames;
  inherit (lib.lists) all;
  inherit (lib.types)
    addCheck
    attrsWith
    bool
    enum
    nonEmptyStr
    nullOr
    package
    strMatching
    submodule
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
    The option type of a redistributable system name.

    # Type

    ```
    redistSystem :: OptionType
    ```
  */
  redistSystem = enum cudaLib.data.redistSystems // {
    name = "redistSystem";
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
