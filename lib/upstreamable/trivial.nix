{ lib }:
let
  inherit (builtins)
    match
    pathExists
    readDir
    removeAttrs
    substring
    ;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.strings) concatStringsSep removePrefix;
in
{
  # TODO: Document.
  addNameToFetchFromGitLikeArgs =
    fetcher:
    let
      fetcherSupportsTagArg = fetcher.__functionArgs ? tag;
    in
    args:
    if args ? name then
      # Use `name` when provided.
      args
    else
      let
        inherit (args) owner repo rev;
        hasTagArg = args ? tag;
        revStrippedRefsTags = removePrefix "refs/tags/" rev;
        tagInRev = revStrippedRefsTags != rev;
        isHash = match "^[0-9a-f]{40}$" rev == [ ];
        shortHash = substring 0 8 rev;

        # If the fetcher doesn't support a `tag` argument, remove it and populate rev.
        supportOldTaglessArgs =
          if (!fetcherSupportsTagArg && hasTagArg) then
            removeAttrs args [ "tag" ]
            // optionalAttrs (!fetcherSupportsTagArg && hasTagArg) {
              rev =
                # Exactly one of tag or rev must be supplied.
                assert args.rev or null == null;
                "refs/tags/${args.tag}";
            }
          else
            args;
      in
      supportOldTaglessArgs
      // {
        name = concatStringsSep "-" [
          owner
          repo
          (
            # If tag is present that takes precedence.
            if args.tag or null != null then
              args.tag
            # If there's no tag, then rev *must* exist.
            else if tagInRev then
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
