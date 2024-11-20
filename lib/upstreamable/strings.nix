{ lib }:
let
  inherit (lib.strings) versionAtLeast versionOlder;
  inherit (lib.trivial) flip;
  inherit (lib.upstreamable.versions) versionAtMost versionNewer;
in
{
  /**
    Predicate to determine if a version string is at most a given version.

    # Type

    ```
    versionAtMost :: Version -> Version -> Bool
    ```

    # Arguments

    a
    : A version string

    b
    : A version string

    # Returns

    A boolean indicating if `a` is at most `b`.

    # Example

    ```nix
    lib.upstreamable.strings.versionAtMost "1.2.3" "1.2.4"
    => true
    ```

    ```nix
    lib.upstreamable.strings.versionAtMost "1.2.4" "1.2.4"
    => true
    ```

    ```nix
    lib.upstreamable.strings.versionAtMost "1.2.5" "1.2.4"
    => false
    ```
  */
  versionAtMost = flip versionAtLeast;

  /**
    Predicate to determine if a version string is new than a given version.

    # Type

    ```
    versionNewer :: Version -> Version -> Bool
    ```

    # Arguments

    a
    : A version string

    b
    : A version string

    # Returns

    A boolean indicating if `a` is newer than `b`.

    # Example

    ```nix
    lib.upstreamable.strings.versionNewer "1.2.3" "1.2.4"
    => false
    ```

    ```nix
    lib.upstreamable.strings.versionNewer "1.2.4" "1.2.4"
    => false
    ```

    ```nix
    lib.upstreamable.strings.versionNewer "1.2.5" "1.2.4"
    => true
    ```
  */
  versionNewer = flip versionOlder;

  /**
    Predicate to determine if a version is bounded (exclusive) by two other versions.

    # Type

    ```
    versionBoundedExclusive :: Version -> Version -> Version -> Bool
    ```

    # Arguments

    min
    : A version string

    max
    : A version string

    v
    : A version string

    # Returns

    A boolean indicating if `v` is between (exclusive) `min` and `max`.

    # Example

    ```nix
    lib.upstreamable.strings.versionBoundedExclusive "1.2.3" "1.2.5" "1.2.4"
    => true
    ```

    ```nix
    lib.upstreamable.strings.versionBoundedExclusive "1.2.3" "1.2.5" "1.2.3"
    => false
    ```

    ```nix
    lib.upstreamable.strings.versionBoundedExclusive "1.2.3" "1.2.5" "1.2.5"
    => false
    ```
  */
  versionBoundedExclusive =
    min: max: v:
    versionNewer min v && versionOlder max v;

  /**
    Predicate to determine if a version is bounded (inclusive) by two other versions.

    # Type

    ```
    versionBoundedInclusive :: Version -> Version -> Version -> Bool
    ```

    # Arguments

    min
    : A version string

    max
    : A version string

    v
    : A version string

    # Returns

    A boolean indicating if `v` is between (inclusive) `min` and `max`.

    # Example

    ```nix
    lib.upstreamable.strings.versionBoundedInclusive "1.2.3" "1.2.5" "1.2.4"
    => true
    ```

    ```nix
    lib.upstreamable.strings.versionBoundedInclusive "1.2.3" "1.2.5" "1.2.3"
    => true
    ```

    ```nix
    lib.upstreamable.strings.versionBoundedInclusive "1.2.3" "1.2.5" "1.2.5"
    => true
    ```
  */
  versionBoundedInclusive =
    min: max: v:
    versionAtLeast min v && versionAtMost max v;
}
