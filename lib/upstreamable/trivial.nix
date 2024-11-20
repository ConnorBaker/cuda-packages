{ lib }:
let
  inherit (builtins) pathExists readDir;
  inherit (lib.attrsets) optionalAttrs;
in
{
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
    lib.upstreamable.trivial.readDirIfExists ./foo
    => { bar = "regular"; baz = "regular"; }
    ```

    Assume the directory `./oops` does not exist.

    ```nix
    lib.upstreamable.trivial.readDirIfExists ./oops
    => { }
    ```
  */
  readDirIfExists = path: optionalAttrs (pathExists path) (readDir path);
}
