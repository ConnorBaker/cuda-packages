{
  autoAddDriverRunpath,
  autoPatchelfHook,
  cudaRunpathFixupHook,
  lib,
  patchelf,
  runCommand,
  stdenv,
  testers,
}:
let
  inherit (lib.strings) concatMapStringsSep optionalString;
  inherit (testers) testBuildFailure;

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

  # Tests for cudaRunpathFixupHookOrderCheckPhase.
  cudaRunpathFixupHookOrderCheckPhase = {
    no-autoPatchelfHook = cApplication.overrideAttrs (prevAttrs: {
      name = "no-autoPatchelfHook";
      nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
        cudaRunpathFixupHook
      ];
    });

    before-autoPatchelfHook =
      runCommand "before-autoPatchelfHook"
        {
          failed = testBuildFailure (
            cApplication.overrideAttrs (prevAttrs: {
              name = "before-autoPatchelfHook-inner";
              nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
                cudaRunpathFixupHook
                autoPatchelfHook
              ];
            })
          );
        }
        ''
          (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
          grep -F \
            "ERROR: cudaRunpathFixupHookOrderCheckPhase: autoPatchelfPostFixup must run before 'autoFixElfFiles cudaRunpathFixup'" \
            "$failed/testBuildFailure.log"
          touch $out
        '';

    after-autoPatchelfHook = cApplication.overrideAttrs (prevAttrs: {
      name = "after-autoPatchelfHook";
      nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
        autoPatchelfHook
        cudaRunpathFixupHook
      ];
    });

    no-autoAddDriverRunpath = cApplication.overrideAttrs (prevAttrs: {
      name = "no-autoAddDriverRunpath";
      nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
        cudaRunpathFixupHook
      ];
    });

    before-autoAddDriverRunpath =
      runCommand "before-autoAddDriverRunpath"
        {
          failed = testBuildFailure (
            cApplication.overrideAttrs (prevAttrs: {
              name = "before-autoAddDriverRunpath-inner";
              nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
                cudaRunpathFixupHook
                autoAddDriverRunpath
              ];
            })
          );
        }
        ''
          (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
          grep -F \
            "ERROR: cudaRunpathFixupHookOrderCheckPhase: 'autoFixElfFiles addDriverRunpath' must run before 'autoFixElfFiles cudaRunpathFixup'" \
            "$failed/testBuildFailure.log"
          touch $out
        '';

    after-autoAddDriverRunpath = cApplication.overrideAttrs (prevAttrs: {
      name = "after-autoAddDriverRunpath";
      nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
        autoAddDriverRunpath
        cudaRunpathFixupHook
      ];
    });
  };

  # Tests for cudaRunpathFixup.
  cudaRunpathFixup =
    let
      inherit (cudaRunpathFixupHook.passthru.substitutions) cudaCompatLibDir cudaStubLibDir driverLibDir;

      # TODO: Factor out utility to make an associative array counting the number of times each
      # runpath entry appears in the output.

      mkCApplicationWithRunpathEntries =
        {
          name,
          runpathEntries ? [ ],
          postHookCheck,
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
          doCheck = true; # Enables installCheckPhase
          nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
            cudaRunpathFixupHook
            patchelf
          ];
          postBuild =
            prevAttrs.postBuild or ""
            # Newlines are important here to separate the commands.
            + optionalString (runpathEntries != [ ]) ''
              export ORIGINAL_RPATH="$(patchelf --print-rpath main)"
              nixLog "ORIGINAL_RPATH: $ORIGINAL_RPATH"

              ${rpathModificationSteps}

              export PRE_HOOK_RPATH="$(patchelf --print-rpath main)"
              nixLog "PRE_HOOK_RPATH: $PRE_HOOK_RPATH"
            '';
          # Disable automatic shrinking of runpaths which removes our doubling of paths since they are not used.
          dontPatchELF = true;
          installCheckPhase = ''
            runHook preInstallCheck
            export POST_HOOK_RPATH="$(patchelf --print-rpath $out/bin/main)"
            nixLog "POST_HOOK_RPATH: $POST_HOOK_RPATH"

            ${postHookCheck}

            runHook postInstallCheck
          '';
        });
    in
    {
      no-rpath-change = mkCApplicationWithRunpathEntries {
        name = "no-rpath-change";
        runpathEntries = [ ];
        postHookCheck = ''
          nixLog "Checking that the runpath is unchanged when our entries are not present"
          test "''${POST_HOOK_RPATH:?}" = "''${ORIGINAL_RPATH:?}"
        '';
      };

      # TODO: Tests for Jetson builds where cudaCompatLibDir is present.

      # TODO: Tests for ordering of cudaCompatLibDir and driverLibDir.
      cudaStubLibDir = mkCApplicationWithRunpathEntries {
        name = "cudaStubLibDir";
        runpathEntries = [ cudaStubLibDir ];
        postHookCheck = ''
          nixLog "Checking cudaStubLibDir is gone"
          if [[ "''${POST_HOOK_RPATH:?}" == *"''${cudaStubLibDir:?}"* ]]; then
            nixErrorLog "Unexpected cudaStubLibDir in rpath: ''${POST_HOOK_RPATH:?}"
            exit 1
          fi
          nixLog "Checking driverLibDir is present"
          if [[ "''${POST_HOOK_RPATH:?}" != *"''${driverLibDir:?}"* ]]; then
            nixErrorLog "Expected driverLibDir in rpath: ''${POST_HOOK_RPATH:?}"
            exit 1
          fi
        '';
      };

      # TODO: This is only true on non-Jetson builds or when cuda_compat is set to null.
      # Otherwise, driverLibDir is prefixed with cudaCompatLibDir.
      driverLibDir = mkCApplicationWithRunpathEntries {
        name = "driverLibDir";
        runpathEntries = [ driverLibDir ];
        postHookCheck = ''
          nixLog "Checking that the runpath is unchanged when only driverLibDir is present"
          test "''${POST_HOOK_RPATH:?}" = "''${ORIGINAL_RPATH:?}"
        '';
      };

      # Test combinations.

      cudaStubLibDir-cudaStubLibDir = mkCApplicationWithRunpathEntries {
        name = "cudaStubLibDir-cudaStubLibDir";
        runpathEntries = [
          cudaStubLibDir
          cudaStubLibDir
        ];
        postHookCheck = ''
          nixLog "Checking cudaStubLibDir is gone"
          if [[ "''${POST_HOOK_RPATH:?}" == *"''${cudaStubLibDir:?}"* ]]; then
            nixErrorLog "Unexpected cudaStubLibDir in rpath: ''${POST_HOOK_RPATH:?}"
            exit 1
          fi
          nixLog "Checking driverLibDir is present"
          if [[ "''${POST_HOOK_RPATH:?}" != *"''${driverLibDir:?}"* ]]; then
            nixErrorLog "Expected driverLibDir in rpath: ''${POST_HOOK_RPATH:?}"
            exit 1
          fi
        '';
      };

      # TODO: Test multiplicity of resulting runpath entries to ensure no duplicates.
      cudaStubLibDir-driverLibDir = mkCApplicationWithRunpathEntries {
        name = "cudaStubLibDir-driverLibDir";
        runpathEntries = [
          cudaStubLibDir
          driverLibDir
        ];
        postHookCheck = ''
          nixLog "Checking cudaStubLibDir is gone"
          if [[ "''${POST_HOOK_RPATH:?}" == *"''${cudaStubLibDir:?}"* ]]; then
            nixErrorLog "Unexpected cudaStubLibDir in rpath: ''${POST_HOOK_RPATH:?}"
            exit 1
          fi
          nixLog "Checking driverLibDir is present"
          if [[ "''${POST_HOOK_RPATH:?}" != *"''${driverLibDir:?}"* ]]; then
            nixErrorLog "Expected driverLibDir in rpath: ''${POST_HOOK_RPATH:?}"
            exit 1
          fi
        '';
      };

      driverLibDir-cudaStubLibDir = mkCApplicationWithRunpathEntries {
        name = "driverLibDir-cudaStubLibDir";
        runpathEntries = [
          driverLibDir
          cudaStubLibDir
        ];
        postHookCheck = ''
          nixLog "Checking cudaStubLibDir is gone"
          if [[ "''${POST_HOOK_RPATH:?}" == *"''${cudaStubLibDir:?}"* ]]; then
            nixErrorLog "Unexpected cudaStubLibDir in rpath: ''${POST_HOOK_RPATH:?}"
            exit 1
          fi
          nixLog "Checking driverLibDir is present"
          if [[ "''${POST_HOOK_RPATH:?}" != *"''${driverLibDir:?}"* ]]; then
            nixErrorLog "Expected driverLibDir in rpath: ''${POST_HOOK_RPATH:?}"
            exit 1
          fi
        '';
      };

      # TODO: Without a histogram, this doesn't make sense as a test.
      # driverLibDir-driverLibDir = mkCApplicationWithRunpathEntries {
      #   name = "driverLibDir-driverLibDir";
      #   runpathEntries = [
      #     driverLibDir
      #     driverLibDir
      #   ];
      #   postHookCheck = ''
      #     nixLog "Checking cudaStubLibDir is gone"
      #     if [[ "''${POST_HOOK_RPATH:?}" == *"''${cudaStubLibDir:?}"* ]]; then
      #       nixErrorLog "Unexpected cudaStubLibDir in rpath: ''${POST_HOOK_RPATH:?}"
      #       exit 1
      #     fi
      #     nixLog "Checking driverLibDir is present"
      #     if [[ "''${POST_HOOK_RPATH:?}" != *"''${driverLibDir:?}"* ]]; then
      #       nixErrorLog "Expected driverLibDir in rpath: ''${POST_HOOK_RPATH:?}"
      #       exit 1
      #     fi
      #   '';
      # };
    };
in
{
  inherit cudaRunpathFixup cudaRunpathFixupHookOrderCheckPhase;
}
