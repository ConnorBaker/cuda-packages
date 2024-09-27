{
  cuda_cudart ? null,
  cuda-lib,
  lib,
}:
let
  inherit (lib.lists) optionals;
  inherit (lib.strings) versionOlder;
in
finalAttrs: prevAttrs: {
  badPlatformsConditions =
    prevAttrs.badPlatformsConditions
    // cuda-lib.utils.mkMissingPackagesBadPlatformsConditions { inherit cuda_cudart; };
  buildInputs =
    prevAttrs.buildInputs or [ ]
    ++ optionals (versionOlder finalAttrs.version "0.4") [ cuda_cudart ];
}
