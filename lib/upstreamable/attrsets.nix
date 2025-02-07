{ lib }:
let
  inherit (builtins)
    deepSeq
    genericClosure
    getContext
    tryEval
    typeOf
    unsafeDiscardStringContext
    ;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets)
    attrNames
    attrValues
    catAttrs
    getAttr
    getAttrFromPath
    hasAttr
    isAttrs
    isDerivation
    listToAttrs
    nameValuePair
    showAttrPath
    ;
  inherit (lib.debug) traceIf;
  inherit (lib.fixedPoints) makeExtensible;
  inherit (lib.lists)
    concatMap
    head
    last
    map
    ;
  inherit (lib.trivial) const pipe;
  inherit (lib.upstreamable.attrsets)
    attrPaths
    flattenAttrs
    drvAttrPathsStrategy
    drvAttrPathsStrategyImpl
    ;
in
{
  /**
    Produces a list of attribute paths for a given attribute set.

    # Type

    ```
    attrPaths :: { includeCond :: List String -> Any -> Bool
                 , recurseCond :: List String -> Any -> Bool
                 , trace :: ?Bool = false
                 }
              -> AttrSet
              -> List (List String)
    ```

    # Arguments

    includeCond
    : A function that takes an attribute path and a value and returns a boolean, controlling whether the attribute
    path should be included in the output.

    recurseCond
    : A function that takes an attribute path and a value and returns a boolean, controlling whether the attribute
    path should be recursed into.

    attrs
    : The attribute set to generate attribute paths for.
  */
  attrPaths =
    {
      includeCond,
      recurseCond,
      trace ? false,
    }:
    let
      maybeTrace = traceIf trace;
      go =
        parentAttrPath: parentAttrs:
        concatMap (
          name:
          let
            attrPath = parentAttrPath ++ [ name ];
            value = getAttr name parentAttrs;
            include = includeCond attrPath value;
            recurse = recurseCond attrPath value;
          in
          (
            if include then
              maybeTrace "lib.attrsets.attrPaths: including attribute ${showAttrPath attrPath}" [ attrPath ]
            else
              maybeTrace "lib.attrsets.attrPaths: excluding attribute ${showAttrPath attrPath}" [ ]
          )
          ++ (
            if recurse then
              maybeTrace "lib.attrsets.attrPaths: recursing into attribute ${showAttrPath attrPath}" (
                go attrPath value
              )
            else
              maybeTrace "lib.attrsets.attrPaths: not recursing into attribute ${showAttrPath attrPath}" [ ]
          )
        ) (attrNames parentAttrs);
    in
    attrs:
    assert assertMsg (isAttrs attrs) "lib.attrsets.attrPaths: `attrs` must be an attribute set";
    go [ ] attrs;

  # Credit for this strategy goes to Adam Joseph and is taken from their work on
  # https://github.com/NixOS/nixpkgs/pull/269356.
  drvAttrPathsStrategyImpl = makeExtensible (final: {
    # No release package attrpath may have any of these attrnames as
    # its initial component.
    #
    # If you can find a way to remove any of these entries without
    # causing CI to fail, please do so.
    #
    excludeAtTopLevel = {
      AAAAAASomeThingsFailToEvaluate = null;

      #  spliced packagesets
      __splicedPackages = null;
      pkgsBuildBuild = null;
      pkgsBuildHost = null;
      pkgsBuildTarget = null;
      pkgsHostHost = null;
      pkgsHostTarget = null;
      pkgsTargetTarget = null;
      buildPackages = null;
      targetPackages = null;

      # cross packagesets
      pkgsLLVM = null;
      pkgsMusl = null;
      pkgsStatic = null;
      pkgsCross = null;
      pkgsx86_64Darwin = null;
      pkgsi686Linux = null;
      pkgsLinux = null;
      pkgsExtraHardening = null;
    };

    # No release package attrname may have any of these at a component
    # anywhere in its attrpath.  These are the names of gigantic
    # top-level attrsets that have leaked into so many sub-packagesets
    # that it's easier to simply exclude them entirely.
    #
    # If you can find a way to remove any of these entries without
    # causing CI to fail, please do so.
    #
    excludeAtAnyLevel = {
      lib = null;
      override = null;
      __functor = null;
      __functionArgs = null;
      __splicedPackages = null;
      newScope = null;
      scope = null;
      pkgs = null;
      callPackage = null;
      mkDerivation = null;
      overrideDerivation = null;
      overrideScope = null;
      overrideScope' = null;

      # Special case: lib/types.nix leaks into a lot of nixos-related
      # derivations, and does not eval deeply.
      type = null;
    };

    isExcluded =
      attrPath:
      hasAttr (head attrPath) final.excludeAtTopLevel || hasAttr (last attrPath) final.excludeAtAnyLevel;

    # Include the attribute so long as it has a non-null drvPath.
    # NOTE: We must wrap with `tryEval` and `deepSeq` to catch values which are just `throw`s.
    # NOTE: Do not use `meta.available` because it does not (by default) recursively check dependencies, and requires
    # an undocumented config option (checkMetaRecursively) to do so:
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/check-meta.nix#L496
    # The best we can do is try to compute the drvPath and see if it throws.
    # What we really need is something like:
    # https://github.com/NixOS/nixpkgs/pull/245322
    includeCond =
      attrPath: value:
      let
        unsafeTest = isDerivation value && value.drvPath or null != null;
        attempt = tryEval (deepSeq unsafeTest unsafeTest);
      in
      !(final.isExcluded attrPath) && attempt.success && attempt.value;

    # Recurse when recurseForDerivations is not set.
    recurseByDefault = false;

    # Recurse so long as the attribute set:
    # - is not a derivation or set __recurseIntoDerivationForReleaseJobs set to true
    # - set recurseForDerivations to true or recurseForDerivations is not set and recurseByDefault is true
    # - does not set __attrsFailEvaluation to true
    # NOTE: We must wrap with `tryEval` and `deepSeq` to catch values which are just `throw`s.
    recurseCond =
      attrPath: value:
      let
        unsafeTest =
          isAttrs value
          && (!(isDerivation value) || value.__recurseIntoDerivationForReleaseJobs or false)
          && value.recurseForDerivations or final.recurseByDefault
          && !(value.__attrsFailEvaluation or false);
        attempt = tryEval (deepSeq unsafeTest unsafeTest);
      in
      !(final.isExcluded attrPath) && attempt.success && attempt.value;
  });

  drvAttrPathsStrategy = {
    inherit (drvAttrPathsStrategyImpl) includeCond recurseCond;
  };

  drvAttrPathsRecurseByDefaultStrategy = {
    inherit (drvAttrPathsStrategyImpl.extend (_: _: { recurseByDefault = true; }))
      includeCond
      recurseCond
      ;
  };

  /**
    TODO: Work on docs.

    # Type

    ```
    flattenAttrs :: { includeCond :: List String -> Any -> Bool
                    , recurseCond :: List String -> Any -> Bool
                    , trace :: ?Bool = false
                    }
                 -> AttrSet
                 -> AttrSet
    ```
  */
  flattenAttrs =
    strategy: attrs:
    pipe attrs [
      (attrPaths strategy)
      (map (attrPath: nameValuePair (showAttrPath attrPath) (getAttrFromPath attrPath attrs)))
      listToAttrs
    ];

  /**
    TODO: Work on docs.

    # Type

    ```
    flattenDrvTree :: AttrSet -> AttrSet
    ```
  */
  flattenDrvTree = flattenAttrs drvAttrPathsStrategy;

  # TODO: Docs
  collectDepsRecursive =
    let
      mkItem = dep: {
        # String interpolation is easier than dep.outPath with a fallback to "${dep}" in the case of a path or string with context.
        key = unsafeDiscardStringContext "${dep}";
        inherit dep;
      };

      # listStrategy :: List Any -> List (Derivation | Path)
      listStrategy = concatMap getDepsFromValueSingleStep;
      # Attribute names can't be paths or strings with context.
      # setStrategy :: Attrs Any -> List (Derivation | Path)
      setStrategy = attrs: if isDerivation attrs then [ attrs ] else listStrategy (attrValues attrs);
      # stringStrategy :: String -> List Path
      stringStrategy = string: attrNames (getContext string);
      # pathStrategy :: Path -> List Path
      pathStrategy = path: [ path ];
      # fallbackStrategy :: a -> List (Derivation | Path)
      fallbackStrategy = const [ ];

      strategies = {
        list = listStrategy;
        set = setStrategy;
        string = stringStrategy;
        path = pathStrategy;
      };

      # getDrvsFromValueSingleStep :: a -> List (Derivation | Path)
      # type :: "int" | "bool" | "string" | "path" | "null" | "set" | "list" | "lambda" | "float"
      getDepsFromValueSingleStep = value: (strategies.${typeOf value} or fallbackStrategy) value;
    in
    drvs:
    catAttrs "dep" (genericClosure {
      startSet = map mkItem drvs;
      # If we don't have drvAttrs then it's not a derivation produced by mkDerivation and we can just return
      # since there's no further processing we can do.
      # NOTE: Processing drvAttrs is safer than trying to process the attribute set resulting from mkDerivation.
      operator =
        item:
        if item.dep ? drvAttrs then map mkItem (getDepsFromValueSingleStep item.dep.drvAttrs) else [ ];
    });
}
