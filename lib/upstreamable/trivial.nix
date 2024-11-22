{ lib }:
let
  inherit (builtins)
    match
    pathExists
    readDir
    substring
    ;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.strings) concatStringsSep removePrefix;
in
{
  # TODO: Document.
  addNameToFetchFromGitLikeArgs =
    args:
    if args ? name then
      # Use `name` when provided.
      args
    else
      let
        inherit (args) owner repo rev;
        revStrippedRefsTags = removePrefix "refs/tags/" rev;
        isTag = revStrippedRefsTags != rev;
        isHash = match "^[0-9a-f]{40}$" rev == [ ];
        shortHash = substring 0 8 rev;
      in
      args
      // {
        name = concatStringsSep "-" [
          owner
          repo
          (
            if isTag then
              revStrippedRefsTags
            else if isHash then
              shortHash
            else
              throw "Expected either a tag or a hash for the revision"
          )
        ];
      };

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
