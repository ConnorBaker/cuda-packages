# NOTE: Tests for dontCompressCudaFatbin option go here.
{
  nvccHook,
  stdenv,
}:
let
  cudaDontCompressCheck =
    drvArgs@{
      name,
      ...
    }:
    stdenv.mkDerivation (
      {
        __structuredAttrs = true;
        strictDeps = true;
        name = "${nvccHook.name}-${name}";
        src = null;
        dontUnpack = true;
        nativeBuildInputs = [ nvccHook ];
        configurePhaseCheckScript = ''
          nixErrorLog "configurePhaseCheckScript should be set!"
          exit 1
        '';
        configurePhase = ''
          runHook preConfigure
          runHook configurePhaseCheckScript
          runHook postConfigure
        '';
        postInstall = ''
          touch $out
        '';
      }
      // builtins.removeAttrs drvArgs [ "name" ]
    );
in
{
  flag-unset = cudaDontCompressCheck {
    name = "flag-unset";
    configurePhaseCheckScript = ''
      if [[ $NVCC_PREPEND_FLAGS != *"-Xfatbin=-compress-all"* ]]; then
        nixErrorLog "NVCC_PREPEND_FLAGS does not contain -Xfatbin=-compress-all but dontCompressCudaFatbin is unset"
        exit 1
      fi
    '';
  };

  flag-set-false = cudaDontCompressCheck {
    name = "flag-set-false";
    dontCompressCudaFatbin = false;
    configurePhaseCheckScript = ''
      if [[ $NVCC_PREPEND_FLAGS != *"-Xfatbin=-compress-all"* ]]; then
        nixErrorLog "NVCC_PREPEND_FLAGS does not contain -Xfatbin=-compress-all but dontCompressCudaFatbin is set to false"
        exit 1
      fi
    '';
  };

  flag-set-true = cudaDontCompressCheck {
    name = "flag-set-true";
    dontCompressCudaFatbin = true;
    configurePhaseCheckScript = ''
      if [[ $NVCC_PREPEND_FLAGS == *"-Xfatbin=-compress-all"* ]]; then
        nixErrorLog "NVCC_PREPEND_FLAGS should not contain -Xfatbin=-compress-all when dontCompressCudaFatbin is set to true"
        exit 1
      fi
    '';
  };
}
