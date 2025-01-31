{ lib }:
let
  inherit (lib.lists) take;
  inherit (lib.strings) concatStringsSep replaceStrings;
  inherit (lib.trivial) pipe;
  inherit (lib.versions) splitVersion;
  inherit (lib.upstreamable.versions) trimComponents;
in
{
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
    lib.upstreamable.versions.dropDots "1.2.3"
    => "123"
    ```
  */
  dropDots = replaceStrings [ "." ] [ "" ];

  /**
    Extracts the major, minor, and patch version from a string.

    # Example

    ```nix
    lib.cuda.utils.majorMinorPatch "11.0.3.4"
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
    lib.upstreamable.versions.trimComponents 1 "1.2.3.4"
    => "1"
    ```

    ```nix
    lib.upstreamable.versions.trimComponents 3 "1.2.3.4"
    => "1.2.3"
    ```

    ```nix
    lib.upstreamable.versions.trimComponents 9 "1.2.3.4"
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
