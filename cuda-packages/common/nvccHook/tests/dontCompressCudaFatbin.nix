{
  lib,
  nvccHook,
  stdenv,
  ...
}:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.strings) optionalString;
  mkCudaDontCompressCheck =
    {
      check,
      dontCompressCudaFatbin, # When null, use the default value the hook provides.
      name,
    }:
    stdenv.mkDerivation (
      prevAttrs:
      {
        name = name + optionalString (prevAttrs.__structuredAttrs or false) "-structuredAttrs";
        strictDeps = true;
        src = null;
        dontUnpack = true;
        nativeBuildInputs = [ nvccHook ];
        configurePhase = ''
          runHook preConfigure
          ${check}
          runHook postConfigure
        '';
        postInstall = ''
          touch $out
        '';
      }
      // optionalAttrs (dontCompressCudaFatbin != null) {
        inherit dontCompressCudaFatbin;
      }
    );
in
{
  flag-unset = mkCudaDontCompressCheck {
    name = "flag-unset";
    dontCompressCudaFatbin = null;
    check = ''
      if [[ $NVCC_PREPEND_FLAGS != *"-Xfatbin=-compress-all"* ]]; then
        nixErrorLog "NVCC_PREPEND_FLAGS does not contain -Xfatbin=-compress-all but dontCompressCudaFatbin is unset"
        exit 1
      fi
    '';
  };

  flag-set-false = mkCudaDontCompressCheck {
    name = "flag-set-false";
    dontCompressCudaFatbin = false;
    check = ''
      if [[ $NVCC_PREPEND_FLAGS != *"-Xfatbin=-compress-all"* ]]; then
        nixErrorLog "NVCC_PREPEND_FLAGS does not contain -Xfatbin=-compress-all but dontCompressCudaFatbin is set to false"
        exit 1
      fi
    '';
  };

  flag-set-true = mkCudaDontCompressCheck {
    name = "flag-set-true";
    dontCompressCudaFatbin = true;
    check = ''
      if [[ $NVCC_PREPEND_FLAGS == *"-Xfatbin=-compress-all"* ]]; then
        nixErrorLog "NVCC_PREPEND_FLAGS should not contain -Xfatbin=-compress-all when dontCompressCudaFatbin is set to true"
        exit 1
      fi
    '';
  };
}
