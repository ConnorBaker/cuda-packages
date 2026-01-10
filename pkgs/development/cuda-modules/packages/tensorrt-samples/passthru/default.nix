{
  backendStdenv,
  fetchzip,
  finalAttrs,
  lib,
  stdenvNoCC,
}:
let
  older = lib.versionOlder finalAttrs.version;
  atLeast = lib.versionAtLeast finalAttrs.version;
in
{
  mkTest =
    name: cmdArgs:
    stdenvNoCC.mkDerivation {
      __structuredAttrs = true;

      strictDeps = true;

      name = finalAttrs.name + "-" + name;

      inherit cmdArgs;

      nativeBuildInputs = [
        finalAttrs.finalPackage
      ];

      dontUnpack = true;

      dontConfigure = true;

      buildPhase = ''
        runHook preBuild

        nixLog "running ''${cmdArgs[*]@Q}"
        mkdir -p "$out"
        "''${cmdArgs[@]}" | tee -a "$out/test.log" || {
          nixErrorLog "command failed with exit code $?"
          exit 1
        }

        runHook postBuild
      '';

      installPhase = ''
        touch "$out"
      '';

      # requiredSystemFeatures = [ "cuda" ];
    };

  sample-data =
    let
      # Releases prior to 10.14.1 don't have any sample data available to them, so just use the 10.14.1 release's
      # sample data.
      sample-data_10_14_1 = {
        url = "https://github.com/NVIDIA/TensorRT/releases/download/v10.14/tensorrt_sample_data_20251106.zip";
        hash = "sha256-IA1pH8idtk/7FD1Tf0hKtyP7A5SW/2ugezyBRluG8yk=";
      };
    in
    fetchzip (
      if older "10.14.1" then
        sample-data_10_14_1
      else
        lib.getAttr finalAttrs.version {
          "10.14.1" = sample-data_10_14_1;
        }
    );

  # TODO: A number of the tests fail with 10.2:
  # API Usage Error (Unable to load library: libnvinfer_builder_resource_win.so.10.2.0:
  # libnvinfer_builder_resource_win.so.10.2.0: cannot open shared object file: No such file or directory)
  # TODO: Add tests for trtexec.
  tests = lib.packagesFromDirectoryRecursive {
    callPackage =
      path: _:
      import path {
        inherit (finalAttrs.passthru) mkTest sample-data;
        inherit
          atLeast
          backendStdenv
          finalAttrs
          lib
          older
          ;
      };
    directory = ./tests;
  };
}
