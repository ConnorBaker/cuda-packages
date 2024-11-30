{

  cudaAtLeast,
  lib,
  libnvjitlink ? null,
}:
let
  inherit (lib.attrsets) optionalAttrs recursiveUpdate;
  inherit (lib.cuda.utils) mkMissingPackagesBadPlatformsConditions;
in
prevAttrs: {
  buildInputs =
    prevAttrs.buildInputs
    # Dependency from 12.0 and on
    ++ lib.lists.optionals (cudaAtLeast "12.0") [ libnvjitlink ];
  passthru = recursiveUpdate (prevAttrs.passthru or { }) {
    badPlatformsConditions = mkMissingPackagesBadPlatformsConditions (
      optionalAttrs (cudaAtLeast "12.0") { inherit libnvjitlink; }
    );
  };
}
