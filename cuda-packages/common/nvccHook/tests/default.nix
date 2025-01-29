{
  autoPatchelfHook,
  cuda_cudart,
  cuda_nvcc,
  lib,
  nvccHook,
  patchelf,
  runCommand,
  stdenv,
  testers,
}:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.strings) concatMapStringsSep optionalString;
  inherit (testers) testBuildFailure;

  args = {
    inherit lib nvccHook stdenv;
  };

  args-structuredAttrs = args // {
    stdenv = stdenv.overrideAttrs { __structuredAttrs = true; };
  };

  cApplication = stdenv.mkDerivation {
    # NOTE: Must set name!
    strictDeps = true;
    src = null;
    dontUnpack = true;
    buildPhase = ''
      runHook preBuild
      echo "int main() { return 0; }" > main.c
      cc main.c -o main
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      cp main "$out/bin/"
      runHook postInstall
    '';
  };

  # Tests for dontCompressCudaFatbin option.
  dontCompressCudaFatbin = import ./dontCompressCudaFatbin.nix args;

  # TODO: Remove this when __structuredAttrs is enabled by default.
  dontCompressCudaFatbin-structuredAttrs = import ./dontCompressCudaFatbin.nix args-structuredAttrs;

  # Tests for nvccRunpathCheck.
  nvccRunpathCheck =
    let
      inherit (nvccHook.passthru.substitutions)
        ccVersion
        hostPlatformConfig
        unwrappedCCRoot
        unwrappedCCLibRoot
        ;

      unwrappedCCRootLib = "${unwrappedCCRoot}/lib";
      unwrappedCCRootLib64 = "${unwrappedCCRoot}/lib64";
      unwrappedCCRootGcc = "${unwrappedCCRoot}/gcc/${hostPlatformConfig}/${ccVersion}";
      unwrappedCCLibRootLib = "${unwrappedCCLibRoot}/lib";

      mkCApplicationWithRunpathEntries =
        {
          name,
          runpathEntries ? [ ],
          structuredAttrs ? false,
        }:
        let
          # cudaCompatDir cudaStubDir driverDir
          rpathModificationSteps = concatMapStringsSep "\n" (entry: ''
            nixLog "Adding rpath entry for ${entry}"
            patchelf --add-rpath "${entry}" main
          '') runpathEntries;
        in
        cApplication.overrideAttrs (prevAttrs: {
          inherit name;
          __structuredAttrs = structuredAttrs;
          nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
            nvccHook
            patchelf
          ];
          postBuild =
            prevAttrs.postBuild or ""
            # Newlines are important here to separate the commands.
            + optionalString (runpathEntries != [ ]) ''
              ${rpathModificationSteps}
            '';
          # Disable automatic shrinking of runpaths which removes our doubling of paths since they are not used.
          dontPatchELF = true;
        });
    in
    {
      no-leak = mkCApplicationWithRunpathEntries {
        name = "no-leak";
        runpathEntries = [ ];
      };

      no-leak-structuredAttrs = mkCApplicationWithRunpathEntries {
        name = "no-leak-structuredAttrs";
        structuredAttrs = true;
        runpathEntries = [ ];
      };

      leak-host-cc-root-lib =
        runCommand "leak-host-cc-root-lib"
          {
            failed = testBuildFailure (mkCApplicationWithRunpathEntries {
              name = "leak-host-cc-root-lib-inner";
              runpathEntries = [ unwrappedCCRootLib ];
            });
          }
          ''
            (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
            grep -F 'forbidden path ${unwrappedCCRootLib} exists' "$failed/testBuildFailure.log"
            touch $out
          '';

      leak-host-cc-root-lib-structuredAttrs =
        runCommand "leak-host-cc-root-lib-structuredAttrs"
          {
            failed = testBuildFailure (mkCApplicationWithRunpathEntries {
              name = "leak-host-cc-root-lib-structuredAttrs-inner";
              structuredAttrs = true;
              runpathEntries = [ unwrappedCCRootLib ];
            });
          }
          ''
            (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
            grep -F 'forbidden path ${unwrappedCCRootLib} exists' "$failed/testBuildFailure.log"
            touch $out
          '';

      leak-host-cc-root-lib64 =
        runCommand "leak-host-cc-root-lib64"
          {
            failed = testBuildFailure (mkCApplicationWithRunpathEntries {
              name = "leak-host-cc-root-lib64-inner";
              runpathEntries = [ unwrappedCCRootLib64 ];
            });
          }
          ''
            (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
            grep -F 'forbidden path ${unwrappedCCRootLib64} exists' "$failed/testBuildFailure.log"
            touch $out
          '';

      leak-host-cc-root-lib64-structuredAttrs =
        runCommand "leak-host-cc-root-lib64-structuredAttrs"
          {
            failed = testBuildFailure (mkCApplicationWithRunpathEntries {
              name = "leak-host-cc-root-lib64-structuredAttrs-inner";
              structuredAttrs = true;
              runpathEntries = [ unwrappedCCRootLib64 ];
            });
          }
          ''
            (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
            grep -F 'forbidden path ${unwrappedCCRootLib64} exists' "$failed/testBuildFailure.log"
            touch $out
          '';

      leak-host-cc-root-gcc =
        runCommand "leak-host-cc-root-gcc"
          {
            failed = testBuildFailure (mkCApplicationWithRunpathEntries {
              name = "leak-host-cc-root-gcc-inner";
              runpathEntries = [ unwrappedCCRootGcc ];
            });
          }
          ''
            (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
            grep -F 'forbidden path ${unwrappedCCRootGcc} exists' "$failed/testBuildFailure.log"
            touch $out
          '';

      leak-host-cc-root-gcc-structuredAttrs =
        runCommand "leak-host-cc-root-gcc-structuredAttrs"
          {
            failed = testBuildFailure (mkCApplicationWithRunpathEntries {
              name = "leak-host-cc-root-gcc-structuredAttrs-inner";
              structuredAttrs = true;
              runpathEntries = [ unwrappedCCRootGcc ];
            });
          }
          ''
            (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
            grep -F 'forbidden path ${unwrappedCCRootGcc} exists' "$failed/testBuildFailure.log"
            touch $out
          '';

      leak-host-cc-lib-root-lib =
        runCommand "leak-host-cc-lib-root-lib"
          {
            failed = testBuildFailure (mkCApplicationWithRunpathEntries {
              name = "leak-host-cc-lib-root-lib-inner";
              runpathEntries = [ unwrappedCCLibRootLib ];
            });
          }
          ''
            (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
            grep -F 'forbidden path ${unwrappedCCLibRootLib} exists' "$failed/testBuildFailure.log"
            touch $out
          '';

      leak-host-cc-lib-root-lib-structuredAttrs =
        runCommand "leak-host-cc-lib-root-lib-structuredAttrs"
          {
            failed = testBuildFailure (mkCApplicationWithRunpathEntries {
              name = "leak-host-cc-lib-root-lib-structuredAttrs-inner";
              structuredAttrs = true;
              runpathEntries = [ unwrappedCCLibRootLib ];
            });
          }
          ''
            (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
            grep -F 'forbidden path ${unwrappedCCLibRootLib} exists' "$failed/testBuildFailure.log"
            touch $out
          '';
    };

  # Tests for nvccHookOrderCheckPhase.
  nvccHookOrderCheckPhase = {
    no-autoPatchelfHook = cApplication.overrideAttrs (prevAttrs: {
      name = "no-autoPatchelfHook";
      nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
        nvccHook
      ];
    });

    no-autoPatchelfHook-structuredAttrs = cApplication.overrideAttrs (prevAttrs: {
      name = "no-autoPatchelfHook-structuredAttrs";
      __structuredAttrs = true;
      nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
        nvccHook
      ];
    });

    before-autoPatchelfHook =
      runCommand "before-autoPatchelfHook"
        {
          failed = testBuildFailure (
            cApplication.overrideAttrs (prevAttrs: {
              name = "before-autoPatchelfHook-inner";
              nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
                nvccHook
                autoPatchelfHook
              ];
            })
          );
        }
        ''
          (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
          grep -F \
            "ERROR: nvccHookOrderCheckPhase: autoPatchelfPostFixup must run before 'autoFixElfFiles nvccRunpathCheck'" \
            "$failed/testBuildFailure.log"
          touch $out
        '';

    before-autoPatchelfHook-structuredAttrs =
      runCommand "before-autoPatchelfHook-structuredAttrs"
        {
          failed = testBuildFailure (
            cApplication.overrideAttrs (prevAttrs: {
              name = "before-autoPatchelfHook-structuredAttrs-inner";
              __structuredAttrs = true;
              nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
                nvccHook
                autoPatchelfHook
              ];
            })
          );
        }
        ''
          (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
          grep -F \
            "ERROR: nvccHookOrderCheckPhase: autoPatchelfPostFixup must run before 'autoFixElfFiles nvccRunpathCheck'" \
            "$failed/testBuildFailure.log"
          touch $out
        '';

    after-autoPatchelfHook = cApplication.overrideAttrs (prevAttrs: {
      name = "after-autoPatchelfHook";
      nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
        autoPatchelfHook
        nvccHook
      ];
    });

    after-autoPatchelfHook-structuredAttrs = cApplication.overrideAttrs (prevAttrs: {
      name = "after-autoPatchelfHook-structuredAttrs";
      __structuredAttrs = true;
      nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
        autoPatchelfHook
        nvccHook
      ];
    });
  };
in
{
  inherit dontCompressCudaFatbin nvccHookOrderCheckPhase nvccRunpathCheck;
}
