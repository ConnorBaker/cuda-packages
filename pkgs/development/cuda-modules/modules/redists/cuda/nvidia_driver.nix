{ lib }:
let
  inherit (lib.attrsets) recursiveUpdate;
in
prevAttrs: {
  passthru = recursiveUpdate (prevAttrs.passthru or { }) {
    brokenConditions = {
      "Package is not supported; use drivers from linuxPackages" = true;
    };
  };
}
