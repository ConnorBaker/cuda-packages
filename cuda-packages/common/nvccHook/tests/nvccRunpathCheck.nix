# NOTE: Tests for nvccRunpathCheck go here.
{
  mkCheckExpectedRunpath,
  nvccHook,
  testers,
}:
let
  inherit (nvccHook.passthru.substitutions)
    ccVersion
    hostPlatformConfig
    unwrappedCCRoot
    unwrappedCCLibRoot
    ;
  inherit (testers) runCommand testBuildFailure;

  libDir = "${unwrappedCCRoot}/lib";
  lib64Dir = "${unwrappedCCRoot}/lib64";
  gccDir = "${unwrappedCCRoot}/gcc/${hostPlatformConfig}/${ccVersion}";
  ccLibDir = "${unwrappedCCLibRoot}/lib";

  check =
    {
      name,
      valuesArr,
      expectedArr,
    }:
    mkCheckExpectedRunpath.overrideAttrs (prevAttrs: {
      inherit valuesArr expectedArr;
      name = "${nvccHook.name}-${name}";
      nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [ nvccHook ];
      checkSetupScript = ''
        nixLog "running nvccRunpathCheck on main"
        nvccRunpathCheck main
      '';
    });
in
{
  no-leak-empty = check {
    name = "no-leak-empty";
    valuesArr = [ ];
    expectedArr = [ ];
  };

  no-leak-singleton = check {
    name = "no-leak-singleton";
    valuesArr = [ "cat" ];
    expectedArr = [ "cat" ];
  };

  leak-singleton = runCommand {
    name = "${nvccHook.name}-leak-singleton";
    failed = testBuildFailure (check {
      name = "leak-singleton-inner";
      valuesArr = [ lib64Dir ];
      expectedArr = [ ];
    });
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for error message"
      grep -F \
        "forbidden path ${lib64Dir} exists" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  leak-all = runCommand {
    name = "${nvccHook.name}-leak-all";
    failed = testBuildFailure (check {
      name = "leak-all-inner";
      valuesArr = [
        libDir
        lib64Dir
        gccDir
        ccLibDir
      ];
      expectedArr = [ ];
    });
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for error message for libDir"
      grep -F \
        "forbidden path ${libDir} exists" \
        "$failed/testBuildFailure.log"
      nixLog "Checking for error message for lib64Dir"
      grep -F \
        "forbidden path ${lib64Dir} exists" \
        "$failed/testBuildFailure.log"
      nixLog "Checking for error message for gccDir"
      grep -F \
        "forbidden path ${gccDir} exists" \
        "$failed/testBuildFailure.log"
      nixLog "Checking for error message for ccLibDir"
      grep -F \
        "forbidden path ${ccLibDir} exists" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };

  leak-between-valid = runCommand {
    name = "${nvccHook.name}-leak-between-valid";
    failed = testBuildFailure (check {
      name = "leak-between-valid-inner";
      valuesArr = [
        "cat"
        libDir
        "bee"
      ];
      expectedArr = [
        "cat"
        "bee"
      ];
    });
    script = ''
      nixLog "Checking for exit code 1"
      (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
      nixLog "Checking for error message for libDir"
      grep -F \
        "forbidden path ${libDir} exists" \
        "$failed/testBuildFailure.log"
      nixLog "Test passed"
      touch $out
    '';
  };
}
