# NOTE: Tests for cudaRunpathFixup go here.
{
  cApplication,
  cudaRunpathFixupHook,
  lib,
  patchelf,
  ...
}:
let
  inherit (cudaRunpathFixupHook.passthru.substitutions) cudaStubLibDir driverLibDir;
  inherit (lib.strings) concatMapStringsSep optionalString;

  # TODO: Factor out utility to make an associative array counting the number of times each
  # runpath entry appears in the output.

  # TODO: Jetson tests (cudaCompatLibDir).

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
      name = name + optionalString (prevAttrs.__structuredAttrs or false) "-structuredAttrs";
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
}
