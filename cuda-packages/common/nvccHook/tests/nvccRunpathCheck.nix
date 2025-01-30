# NOTE: Tests for nvccRunpathCheck go here.
{
  cApplication,
  lib,
  nvccHook,
  patchelf,
  runCommand,
  testers,
  ...
}:
let
  inherit (lib.strings) concatMapStringsSep optionalString;
  inherit (nvccHook.passthru.substitutions)
    ccVersion
    hostPlatformConfig
    unwrappedCCRoot
    unwrappedCCLibRoot
    ;
  inherit (testers) testBuildFailure;

  unwrappedCCRootLib = "${unwrappedCCRoot}/lib";
  unwrappedCCRootLib64 = "${unwrappedCCRoot}/lib64";
  unwrappedCCRootGcc = "${unwrappedCCRoot}/gcc/${hostPlatformConfig}/${ccVersion}";
  unwrappedCCLibRootLib = "${unwrappedCCLibRoot}/lib";

  mkCApplicationWithRunpathEntries =
    {
      name,
      runpathEntries ? [ ],
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
}
