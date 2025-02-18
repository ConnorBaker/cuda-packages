{
  lib,
  stdenv,
}:
let
  inherit (lib.strings) optionalString;
in
stdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;

  name = "mkCheckExpectedArrayAndMap";
  src = null;
  dontUnpack = true;
  doCheck = true;

  valuesArr = null;
  valuesMap = null;

  expectedArr = null;
  expectedMap = null;

  preCheckSetupScript =
    optionalString (finalAttrs.valuesArr != null) ''
      nixLog "using valuesArr: $(declare -p valuesArr)"
    ''
    + optionalString (finalAttrs.valuesMap != null) ''
      nixLog "using valuesMap: $(declare -p valuesMap)"
    ''
    + optionalString (finalAttrs.expectedArr != null) ''
      nixLog "using expectedArr: $(declare -p expectedArr)"
      declare -ag actualArr
    ''
    + optionalString (finalAttrs.expectedMap != null) ''
      nixLog "using expectedMap: $(declare -p expectedMap)"
      declare -Ag actualMap
    '';

  # NOTE: checkSetupScript has access to valuesArr, valuesMap, expectedArr, expectedMap, actualArr, and actualMap,
  # but should never touch expectedArr or expectedMap.
  checkSetupScript = ''
    nixErrorLog "no checkSetupScript provided!"
    exit 1
  '';

  postCheckSetupScript =
    optionalString (finalAttrs.expectedArr != null) ''
      nixLog "comparing actualArr against expectedArr"
      nixLog "using actualArr: $(declare -p actualArr)"
      assertArraysAreEqual expectedArr actualArr
      nixLog "actualArr matches expectedArr"
    ''
    + optionalString (finalAttrs.expectedMap != null) ''
      nixLog "comparing actualMap against expectedMap"
      nixLog "using actualMap: $(declare -p actualMap)"
      assertMapsAreEqual expectedMap actualMap
      nixLog "actualMap matches expectedMap"
    '';

  nativeBuildInputs = [
    ./assert-arrays-are-equal.sh
    ./assert-maps-are-equal.sh
  ];

  checkPhase = ''
    runHook preCheck

    nixLog "running preCheckSetupScript"
    runHook preCheckSetupScript

    nixLog "running checkSetupScript"
    runHook checkSetupScript

    nixLog "running postCheckSetupScript"
    runHook postCheckSetupScript

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    nixLog "test passed"
    touch "$out"
    runHook postInstall
  '';
})
