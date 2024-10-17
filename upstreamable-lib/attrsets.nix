{ lib, upstreamable-lib }:
let
  inherit (builtins) deepSeq tryEval;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets)
    foldlAttrs
    genAttrs
    getAttr
    hasAttr
    isAttrs
    isDerivation
    mergeAttrsList
    ;
  inherit (lib.debug) traceIf;
  inherit (lib.lists) concatMap;
  inherit (lib.strings) escapeNixIdentifier;
  inherit (lib.trivial) const flip;
  inherit (upstreamable-lib.attrsets) flattenAttrs;
in
{
  /**
    TODO: Work on docs.

    # Type

    ```
    flattenAttrs :: { attrs :: AttrSet
                    , doTrace :: Bool
                    , excludeAtAnyLevel :: List String
                    , excludeAtTopLevel :: List String
                    , includeCond :: String -> Any -> Bool
                    , includeFunc :: String -> Any -> Any
                    , recurseCond :: String -> Any -> Bool
                    }
                 -> AttrSet
    ```
  */
  flattenAttrs =
    {
      attrs,
      doTrace ? false,
      excludeAtAnyLevel ? [ ],
      excludeAtTopLevel ? [ ],
      includeCond,
      includeFunc,
      recurseCond,
    }:
    let
      # Exclusion conditions using lookups for fast tests.
      excludeAtAnyLevelCond =
        let
          lookup = genAttrs excludeAtAnyLevel (const null);
        in
        flip hasAttr lookup;
      excludeAtTopLevelCond =
        let
          lookup = genAttrs excludeAtTopLevel (const null);
        in
        flip hasAttr lookup;

      # Partially apply.
      maybeTrace = traceIf doTrace;

      # Handle the top-level separately, since a huge number of the packages we have are up there.
      # topLevelStep :: AttrSet -> { included :: List AttrSet, recursable :: List String }
      topLevelStep =
        foldlAttrs
          (
            acc: name: value:
            let
              escapedAttrPath = escapeNixIdentifier name;
            in
            if excludeAtTopLevelCond name then
              maybeTrace "lib.attrsets.flattenAttrs: excluding top-level attribute ${escapedAttrPath}" acc
            else if excludeAtAnyLevelCond name then
              maybeTrace "lib.attrsets.flattenAttrs: excluding any-level attribute ${escapedAttrPath}" acc
            else if recurseCond name value then
              maybeTrace "lib.attrsets.flattenAttrs: marking recursable attribute ${escapedAttrPath}" {
                inherit (acc) included;
                recursable = acc.recursable ++ [ name ];
              }
            else if includeCond name value then
              maybeTrace "lib.attrsets.flattenAttrs: including attribute ${escapedAttrPath}" {
                inherit (acc) recursable;
                included = acc.included ++ [ { ${escapedAttrPath} = includeFunc name value; } ];
              }
            else
              maybeTrace "lib.attrsets.flattenAttrs: excluding attribute ${escapedAttrPath}" acc
          )
          {
            included = [ ];
            # TODO: If evaluation of a top-level package which is from a package set causes initialization of the
            # package set because attribute sets are strict in their keys, are we able to re-use the package set
            # by passing it to the recursive step, rather than just keeping the name?
            # That is, are we evaluating the keys of the package set twice by only keeping the name?
            # Not sure what Nix is able to save across function calls.
            # NOTE: `attrs` is strict in its keys, but the values are thunks. Since we're only getting our values
            # from `attrs`, if the value is forced, it's updated in-place in `attrs` and subsequent accesses will
            # get the updated value (so no re-evaluation).
            recursable = [ ];
          };

      # recursiveStep :: String -> AttrSet -> List AttrSet
      recursiveStep =
        escapedRootAttrPath:
        foldlAttrs (
          acc: name: value:
          let
            # NOTE: This is essentially how showAttrPath works, but we avoid re-applying escapeNixIdentifier to the
            # root.
            escapedAttrPath = "${escapedRootAttrPath}.${escapeNixIdentifier name}";
          in
          if excludeAtAnyLevelCond name then
            maybeTrace "lib.attrsets.flattenAttrs: excluding any-level attribute ${escapedAttrPath}" acc
          else if recurseCond name value then
            maybeTrace "lib.attrsets.flattenAttrs: recursing into attribute ${escapedAttrPath}" (
              acc ++ recursiveStep escapedAttrPath value
            )
          else if includeCond name value then
            maybeTrace "lib.attrsets.flattenAttrs: including attribute ${escapedAttrPath}" (
              acc ++ [ { ${escapedAttrPath} = includeFunc name value; } ]
            )
          else
            maybeTrace "lib.attrsets.flattenAttrs: excluding attribute ${escapedAttrPath}" acc
        ) [ ];

      # NOTE: Performance did not increase when using a function mergeListsList, like attrsets.mergeAttrsList.
      inherit (topLevelStep attrs) included recursable;
      recursed = concatMap (
        name: recursiveStep (escapeNixIdentifier name) (getAttr name attrs)
      ) recursable;
      flattened = mergeAttrsList (included ++ recursed);
    in
    assert assertMsg (isAttrs attrs) "lib.attrsets.flattenAttrs: `attrs` must be an attribute set";
    flattened;

  /**
    TODO: Work on docs.

    Credit for the majority of this function goes to Adam Joseph and is taken from their work on
    https://github.com/NixOS/nixpkgs/pull/269356.

    # Type

    ```
    flattenDrvTree :: AttrSet -> AttrSet
    ```
  */
  flattenDrvTree =
    # TODO: Using a pattern like `args@` causes the defaults to be ignored?
    {
      attrs,

      doTrace ? true,

      # No release package attrpath may have any of these attrnames as
      # its initial component.
      #
      # If you can find a way to remove any of these entries without
      # causing CI to fail, please do so.
      #
      excludeAtTopLevel ? [
        "AAAAAASomeThingsFailToEvaluate"

        #  spliced packagesets
        "__splicedPackages"
        "pkgsBuildBuild"
        "pkgsBuildHost"
        "pkgsBuildTarget"
        "pkgsHostHost"
        "pkgsHostTarget"
        "pkgsTargetTarget"
        "buildPackages"
        "targetPackages"

        # cross packagesets
        "pkgsLLVM"
        "pkgsMusl"
        "pkgsStatic"
        "pkgsCross"
        "pkgsx86_64Darwin"
        "pkgsi686Linux"
        "pkgsLinux"
        "pkgsExtraHardening"
      ],

      # No release package attrname may have any of these at a component
      # anywhere in its attrpath.  These are the names of gigantic
      # top-level attrsets that have leaked into so many sub-packagesets
      # that it's easier to simply exclude them entirely.
      #
      # If you can find a way to remove any of these entries without
      # causing CI to fail, please do so.
      #
      excludeAtAnyLevel ? [
        "lib"
        "override"
        "__functor"
        "__functionArgs"
        "__splicedPackages"
        "newScope"
        "scope"
        "pkgs"
        "callPackage"
        "mkDerivation"
        "overrideDerivation"
        "overrideScope"
        "overrideScope'"

        # Special case: lib/types.nix leaks into a lot of nixos-related
        # derivations, and does not eval deeply.
        "type"
      ],

      # Include the attribute so long as it has a non-null drvPath.
      # TODO: Will this get everything? Do setup hooks have a drvPath?
      # NOTE: We must wrap with `tryEval` and `deepSeq` to catch values which are just `throw`s.
      # NOTE: Do not use `meta.available` because it does not (by default) recursively check dependencies, and requires
      # an undocumented config option (checkMetaRecursively) to do so:
      # https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/check-meta.nix#L496
      # What we really need is something like:
      # https://github.com/NixOS/nixpkgs/pull/245322
      includeCond ?
        let
          cond = value: isDerivation value && value.drvPath or null != null;
        in
        _: value:
        let
          test = cond value;
          attempt = tryEval (deepSeq test test);
        in
        attempt.success && attempt.value,

      # Identity function for now.
      includeFunc ? _: value: value,

      # Recurse so long as the attribute set:
      # - is not a derivation or set __recurseIntoDerivationForReleaseJobs set to true
      # - set recurseForDerivations to true
      # - does not set __attrsFailEvaluation to true
      # NOTE: We must wrap with `tryEval` and `deepSeq` to catch values which are just `throw`s.
      recurseCond ?
        let
          cond =
            value:
            isAttrs value
            && (!(isDerivation value) || value.__recurseIntoDerivationForReleaseJobs or false)
            && value.recurseForDerivations or false
            && !(value.__attrsFailEvaluation or false);
        in
        _: value:
        let
          test = cond value;
          attempt = tryEval (deepSeq test test);
        in
        attempt.success && attempt.value,
    }:
    flattenAttrs {
      inherit
        attrs
        doTrace
        excludeAtAnyLevel
        excludeAtTopLevel
        includeCond
        includeFunc
        recurseCond
        ;
    };
}
