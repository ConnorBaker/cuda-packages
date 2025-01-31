# NOTE: Should not be called by callPackage because it will replace the override.
{
  lib,
  nixLogWithLevelAndFunctionNameHook,
  stdenv,
}:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.customisation) makeOverridable;
  inherit (lib.strings) optionalString;

  mkCheckExpectedArrayAndMap =
    {
      name,
      # NOTE: setup has access to valuesArr, valuesMap, expectedArr, expectedMap, actualArr, actualMap, but should never
      # touch expectedArr or expectedMap.
      setup,
      extraNativeBuildInputs,
      valuesArr,
      valuesMap,
      expectedArr,
      expectedMap,
      derivationArgs,
    }:
    stdenv.mkDerivation (
      {
        inherit name;
        strictDeps = true;
        __structuredAttrs = true;
        src = null;
        nativeBuildInputs = [
          nixLogWithLevelAndFunctionNameHook
          ./assert-arrays-are-equal.sh
          ./assert-maps-are-equal.sh
        ] ++ extraNativeBuildInputs;
        dontUnpack = true;
        doCheck = true;
        checkPhase =
          ''
            runHook preCheck
          ''
          + optionalString (valuesArr != null) ''
            nixLog "using valuesArr: $(declare -p valuesArr)"
          ''
          + optionalString (valuesMap != null) ''
            nixLog "using valuesMap: $(declare -p valuesMap)"
          ''
          + optionalString (expectedArr != null) ''
            nixLog "using expectedArr: $(declare -p expectedArr)"
          ''
          + optionalString (expectedMap != null) ''
            nixLog "using expectedMap: $(declare -p expectedMap)"
          ''
          + ''
            nixLog "running setup"
            ${setup}
            nixLog "setup complete"
          ''
          + optionalString (expectedArr != null) ''
            nixLog "comparing actualArr against expectedArr"
            nixLog "using actualArr: $(declare -p actualArr)"
            assertArraysAreEqual expectedArr actualArr
            nixLog "actualArr matches expectedArr"
          ''
          + optionalString (expectedMap != null) ''
            nixLog "comparing actualMap against expectedMap"
            nixLog "using actualMap: $(declare -p actualMap)"
            assertMapsAreEqual expectedMap actualMap
            nixLog "actualMap matches expectedMap"
          ''
          + ''
            runHook postCheck
          '';
        installPhase = ''
          runHook preInstall
          touch "$out"
          runHook postInstall
        '';
      }
      # Include the following optional attributes if they are not null.
      // optionalAttrs (valuesArr != null) { inherit valuesArr; }
      // optionalAttrs (valuesMap != null) { inherit valuesMap; }
      // optionalAttrs (expectedArr != null) {
        inherit expectedArr;
        actualArr = [ ];
      }
      // optionalAttrs (expectedMap != null) {
        inherit expectedMap;
        actualMap = { };
      }
      // derivationArgs
    );
in
makeOverridable mkCheckExpectedArrayAndMap {
  name = builtins.throw "mkCheckExpectedArrayAndMap: name must be set";
  setup = builtins.throw "mkCheckExpectedArrayAndMap: setup must be set";
  extraNativeBuildInputs = [ ];
  valuesArr = null;
  valuesMap = null;
  expectedArr = null;
  expectedMap = null;
  derivationArgs = { };
}
