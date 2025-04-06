# NOTE: Tests for nvccRunpathFixup go here.
{
  arrayUtilities,
  nvccHook,
  testers,
}:
let
  inherit (arrayUtilities) getRunpathEntries;
  inherit (nvccHook.passthru.substitutions)
    ccVersion
    hostPlatformConfig
    unwrappedCCRoot
    unwrappedCCLibRoot
    ;
  inherit (testers) makeMainWithRunpath testBuildFailure' testEqualArrayOrMap;

  libDir = "${unwrappedCCRoot}/lib";
  lib64Dir = "${unwrappedCCRoot}/lib64";
  gccDir = "${unwrappedCCRoot}/gcc/${hostPlatformConfig}/${ccVersion}";
  ccLibDir = "${unwrappedCCLibRoot}/lib";

  check =
    {
      name,
      runpathEntries,
      expectedRunpathEntries ? runpathEntries, # default to runpathEntries
    }:
    (testEqualArrayOrMap {
      name = "${nvccHook.name}-${name}";
      valuesArray = runpathEntries;
      expectedArray = expectedRunpathEntries;
      script = ''
        nixLog "installing main"
        install -Dm677 "${makeMainWithRunpath { inherit runpathEntries; }}/bin/main" main
        nixLog "running nvccRunpathFixup on main"
        nvccRunpathFixup main
        nixLog "populating actualArray"
        getRunpathEntries main actualArray
      '';
    }).overrideAttrs
      (prevAttrs: {
        nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
          getRunpathEntries
          nvccHook
        ];
      });
in
{
  no-leak-empty = check {
    name = "no-leak-empty";
    runpathEntries = [ ];
  };

  no-leak-singleton = check {
    name = "no-leak-singleton";
    runpathEntries = [ "cat" ];
  };

  leak-singleton = testBuildFailure' {
    name = "${nvccHook.name}-leak-singleton";
    drv = check {
      name = "leak-singleton-inner";
      runpathEntries = [ lib64Dir ];
      expectedRunpathEntries = [ ];
    };
    expectedBuilderLogEntries = [
      "forbidden path ${lib64Dir} exists"
    ];
  };

  leak-all = testBuildFailure' {
    name = "${nvccHook.name}-leak-all";
    drv = check {
      name = "leak-all-inner";
      runpathEntries = [
        libDir
        lib64Dir
        gccDir
        ccLibDir
      ];
      expectedRunpathEntries = [ ];
    };
    expectedBuilderLogEntries = [
      "forbidden path ${libDir} exists"
      "forbidden path ${lib64Dir} exists"
      "forbidden path ${gccDir} exists"
      "forbidden path ${ccLibDir} exists"
    ];
  };

  leak-between-valid = testBuildFailure' {
    name = "${nvccHook.name}-leak-between-valid";
    drv = check {
      name = "leak-between-valid-inner";
      runpathEntries = [
        "cat"
        libDir
        "bee"
      ];
      expectedRunpathEntries = [
        "cat"
        "bee"
      ];
    };
    expectedBuilderLogEntries = [
      "forbidden path ${libDir} exists"
    ];
  };
}
