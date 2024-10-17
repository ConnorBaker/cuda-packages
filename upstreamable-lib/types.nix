{ lib, upstreamable-lib }:
let
  inherit (builtins) toString;
  inherit (lib.trivial) throwIf;
  inherit (lib.types) strMatching;
  inherit (upstreamable-lib.types) versionWithNumComponents;
in
{
  /**
    The option type of a version with a single component.

    # Type

    ```
    majorVersion :: OptionType
    ```
  */
  majorVersion = versionWithNumComponents 1;

  /**
    The option type of a version with two components.

    # Type

    ```
    majorMinorVersion :: OptionType
    ```
  */
  majorMinorVersion = versionWithNumComponents 2;

  /**
    The option type of a version with three components.

    # Type

    ```
    majorMinorPatchVersion :: OptionType
    ```
  */
  majorMinorPatchVersion = versionWithNumComponents 3;

  /**
    The option type of a version with four components.

    # Type

    ```
    majorMinorPatchBuildVersion :: OptionType
    ```
  */
  majorMinorPatchBuildVersion = versionWithNumComponents 4;

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
    throwIf (numComponents < 1) "numComponents must be positive" (
      strMatching "^[[:digit:]]+(\.[[:digit:]]+){${toString (numComponents - 1)}}$"
    );
}
