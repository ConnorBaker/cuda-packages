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
                included = acc.included ++ [
                  {
                    ${escapedAttrPath} = includeFunc name value;
                  }
                ];
              }
            else
              maybeTrace "lib.attrsets.flattenAttrs: excluding attribute ${escapedAttrPath}" acc
          )
          {
            included = [ ];
            recursable = [ ];
          };

      # recursiveStep :: String -> AttrSet -> List AttrSet
      recursiveStep =
        escapedRootAttrPath:
        foldlAttrs (
          acc: name: value:
          let
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
              acc
              ++ [
                {
                  ${escapedAttrPath} = includeFunc name value;
                }
              ]
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

    # Type

    ```
    flattenDrvTree :: AttrSet -> AttrSet
    ```
  */
  flattenDrvTree =
    attrs:
    flattenAttrs {
      inherit attrs;

      # No release package attrpath may have any of these attrnames as
      # its initial component.
      #
      # If you can find a way to remove any of these entries without
      # causing CI to fail, please do so.
      #
      excludeAtTopLevel = [
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
      ];

      # No release package attrname may have any of these at a component
      # anywhere in its attrpath.  These are the names of gigantic
      # top-level attrsets that have leaked into so many sub-packagesets
      # that it's easier to simply exclude them entirely.
      #
      # If you can find a way to remove any of these entries without
      # causing CI to fail, please do so.
      #
      excludeAtAnyLevel = [
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
      ];

      # Recurse so long as the attribute set:
      # - is not a derivation or set __recurseIntoDerivationForReleaseJobs set to true
      # - set recurseForDerivations to true
      # - does not set __attrsFailEvaluation to true
      # NOTE: We must wrap with `tryEval` and `deepSeq` to catch values which are just `throw`s.
      recurseCond =
        _: value:
        let
          lazyDoRecurse =
            isAttrs value
            && (!(isDerivation value) || value.__recurseIntoDerivationForReleaseJobs or false)
            && value.recurseForDerivations or false
            && !(value.__attrsFailEvaluation or false);
          attempt = tryEval (deepSeq lazyDoRecurse lazyDoRecurse);
        in
        attempt.success && attempt.value;

      # Include the attribute so long as it has a non-null drvPath.
      # TODO: Will this get everything? Do setup hooks have a drvPath?
      # NOTE: We must wrap with `tryEval` and `deepSeq` to catch values which are just `throw`s.
      includeCond =
        _: value:
        let
          lazyDrvPathIsNonNull = isDerivation value && value.drvPath or null != null;
          attempt = tryEval (deepSeq lazyDrvPathIsNonNull lazyDrvPathIsNonNull);
        in
        attempt.success && attempt.value;
      doTrace = true;

      # Get the derivation path.
      includeFunc = _: value: value.drvPath;
    };
}
