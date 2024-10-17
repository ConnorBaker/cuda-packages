{ lib }:
let
  inherit (lib.lists) elemAt take;
  inherit (lib.strings) concatStringsSep replaceStrings;
  inherit (lib.trivial) pipe;
  inherit (lib.versions) splitVersion;
in
rec {
  /**
    Get the build version string from a string.

    # Type

    ```
    build :: String -> String
    ```

    # Arguments

    v
    : The version string to retrieve the build version from

    # Example

    ```nix
    upstreamable-lib.versions.build "1.2.3.4"
    => "4"
    ```
  */
  build = componentAt 3;

  /**
    Get the zero-indexed component version string from a string.

    # Type

    ```
    componentAt :: Integer -> String -> String
    ```

    # Arguments

    idx
    : A non-negative integer corresponding to the zero-indexed location of the component to retrieve

    v
    : The version string to retrieve the version component from

    # Example

    ```nix
    upstreamable-lib.versions.componentAt 0 "1.2.3.4"
    => "1"
    ```

    ```nix
    upstreamable-lib.versions.componentAt 3 "1.2.3.4"
    => "4"
    ```
  */
  componentAt = idx: v: elemAt (splitVersion v) idx;

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
    upstreamable-lib.versions.dropDots "1.2.3"
    => "123"
    ```
  */
  dropDots = replaceStrings [ "." ] [ "" ];

  /**
    Extracts the major, minor, and patch version from a string.

    # Example

    ```nix
    cuda-lib.utils.majorMinorPatch "11.0.3.4"
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
    Extracts the major, minor, patch, and build version from a string.

    # Example

    ```nix
    cuda-lib.utils.majorMinorPatchBuild "11.0.3.4"
    => "11.0.3.4"
    ```

    # Type

    ```
    majorMinorPatchBuild :: String -> String
    ```

    # Arguments

    version
    : The version string
  */
  majorMinorPatchBuild = trimComponents 4;

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
    upstreamable-lib.versions.trimComponents 1 "1.2.3.4"
    => "1"
    ```

    ```nix
    upstreamable-lib.versions.trimComponents 3 "1.2.3.4"
    => "1.2.3"
    ```

    ```nix
    upstreamable-lib.versions.trimComponents 9 "1.2.3.4"
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
}
