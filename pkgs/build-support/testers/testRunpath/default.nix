# NOTE: Must be `import`-ed rather than `callPackage`-d to preserve the `override` attribute.
{
  lib,
  patchelf,
  stdenvNoCC,
}:
let
  inherit (builtins) toString;
  inherit (lib) maintainers;
  inherit (lib.attrsets) mapAttrs;
  inherit (lib.customisation) makeOverridable;
  inherit (lib.trivial) const;

  attrValuesToStrings = mapAttrs (const toString);

  testRunpath =
    {
      drv,
      name ? "testRunpath-${drv.name}", # The name of the test

      includeGlob ? "*", # Files matching this pattern are included in tested
      excludeGlob ? "", # Files matching this pattern are excluded from testing

      included ? [ ], # Runpath entires; each entry must be present
      excluded ? [ ], # Runpath entries; each entry which must be absent

      includedWhenAnyIncluded ? { }, # Runpath entry to list of entries; entry e is present if any entry e' in the list is present
      includedWhenAllIncluded ? { }, # Runpath entry to list of entries; entry e is present if all entries e' in the list are present
      includedWhenAnyExcluded ? { }, # Runpath entry to list of entries; entry e is present if any entry e' in the list is absent
      includedWhenAllExcluded ? { }, # Runpath entry to list of entries; entry e is present if all entries e' in the list are absent

      excludedWhenAnyIncluded ? { }, # Runpath entry to list of entries; entry e is absent if any entry e' in the list is present
      excludedWhenAllIncluded ? { }, # Runpath entry to list of entries; entry e is absent if all entries e' in the list are present
      excludedWhenAnyExcluded ? { }, # Runpath entry to list of entries; entry e is absent if any entry e' in the list is absent
      excludedWhenAllExcluded ? { }, # Runpath entry to list of entries; entry e is absent if all entries e' in the list are absent

      precedes ? { }, # Runpath entry to list of entries; entry e precedes each present entry e' in the list
      succeeds ? { }, # Runpath entry to list of entries; entry e succeeds each present entry e' in the list

      # TODO: No way to express conditional precedes/succeeds

      script ? "", # Additional checks run per-output
    }:
    let
      testRunpathRoot = drv.outPath;
    in
    stdenvNoCC.mkDerivation {
      __structuredAttrs = true;
      strictDeps = true;

      inherit name;

      nativeBuildInputs = [
        patchelf
        # Specify the outPath specifically to ensure the desired output is used.
        testRunpathRoot
      ];

      inherit testRunpathRoot;

      inherit includeGlob excludeGlob;

      # TODO: Map over this to convert to strings and discard contexts to avoid pulling in
      # additional dependencies?
      inherit included excluded;
      includedWhenAnyIncluded = attrValuesToStrings includedWhenAnyIncluded;
      includedWhenAllIncluded = attrValuesToStrings includedWhenAllIncluded;
      includedWhenAnyExcluded = attrValuesToStrings includedWhenAnyExcluded;
      includedWhenAllExcluded = attrValuesToStrings includedWhenAllExcluded;
      excludedWhenAnyIncluded = attrValuesToStrings excludedWhenAnyIncluded;
      excludedWhenAllIncluded = attrValuesToStrings excludedWhenAllIncluded;
      excludedWhenAnyExcluded = attrValuesToStrings excludedWhenAnyExcluded;
      excludedWhenAllExcluded = attrValuesToStrings excludedWhenAllExcluded;
      precedes = attrValuesToStrings precedes;
      succeeds = attrValuesToStrings succeeds;

      inherit script;

      buildCommandPath = ./build-command.sh;

      meta = {
        description = "TODO";
        maintainers = [ maintainers.connorbaker ];
      };
    };
in
makeOverridable testRunpath
