# NOTE: We must use `pkgs.runCommand` instead of `testers.runCommand` for negative tests -- those wrapped with
# `testers.testBuildFailure`. This is due to the fact that `testers.testBuildFailure` modifies the derivation such that
# it produces an output containing the exit code, logs, and other things. Since `testers.runCommand` expects the empty
# derivation, it produces a hash mismatch.
{
  patchelf,
  runCommand,
  runCommandCC,
  testers,
  ...
}:
let
  inherit (testers) testBuildFailure' testRunpath;
  main =
    runCommandCC "build-main"
      {
        __structuredAttrs = true;
        strictDeps = true;
        nativeBuildInputs = [ patchelf ];
      }
      ''
        set -eu
        nixLog "Creating a small C application, main"
        echo "int main() { return 0; }" > main.c
        cc main.c -o main
        nixLog "Installing main to $out/bin"
        install -Dm755 main "$out/bin/main"
      '';

  mainWithRunpath =
    runpathEntries:
    runCommand "build-main-with-runpath"
      {
        __structuredAttrs = true;
        strictDeps = true;
        nativeBuildInputs = [
          main
          patchelf
        ];
        inherit runpathEntries;
      }
      ''
        set -eu
        nixLog "Copying main"
        install -Dm755 "${main}/bin/main" ./main

        nixLog "Removing any existing runpath entries from main"
        patchelf --remove-rpath main

        nixLog "Adding runpath entries from runpathEntries to main"
        local entry
        for entry in "''${runpathEntries[@]}"; do
          nixLog "Adding rpath entry for $entry"
          patchelf --add-rpath "$entry" main
        done
        unset entry

        nixLog "Installing main to $out/bin"
        install -Dm755 main "$out/bin/main"
      '';

  a = mainWithRunpath [ "/a" ];
  b = mainWithRunpath [ "/b" ];
  c = mainWithRunpath [ "/c" ];
  a-b-c = mainWithRunpath [
    "/a"
    "/b"
    "/c"
  ];
  b-a-c = mainWithRunpath [
    "/b"
    "/a"
    "/c"
  ];
in
{
  a = testRunpath {
    drv = a;
    included = [ "/a" ];
    excluded = [ "/b" ];
  };

  b = testRunpath {
    drv = b;
    included = [ "/b" ];
  };

  c = testRunpath {
    drv = c;
    included = [ "/c" ];
    excluded = [ "/a" ];
  };

  a-b-c = testRunpath {
    drv = a-b-c;
    # Order doesn't matter
    included = [
      "/b"
      "/a"
    ];
    # Preceds and succeeds are conditioned on existence
    precedes = {
      "/a" = [
        "/c"
        "/b"
        "/d" # Doesn't exist
      ];
      "/b" = [ "/c" ];
    };
    succeeds = {
      "/c" = [
        "/a"
        "/b"
        "/d" # Doesn't exist
      ];
      "/b" = [ "/a" ];
    };
  };

  b-a-c-failure = testBuildFailure' {
    drv = testRunpath {
      drv = b-a-c;
      included = [ "/d" ];
      excluded = [
        "/a"
        "/b"
        "/c"
      ];
      precedes = {
        "/a" = [
          "/a"
          "/b"
        ];
        "/b" = [ "/b" ];
        "/c" = [
          "/a"
          "/b"
          "/c"
        ];
      };
      succeeds = {
        "/a" = [
          "/a"
          "/c"
        ];
        "/b" = [
          "/b"
          "/a"
          "/c"
        ];
        "/c" = [ "/c" ];
      };
    };
    expectedBuilderLogEntries = [
      "ERROR: testIncluded: /d not found in runpath of ${b-a-c}/bin/main"
      "ERROR: testExcluded: /a found in runpath of ${b-a-c}/bin/main"
      "ERROR: testExcluded: /b found in runpath of ${b-a-c}/bin/main"
      "ERROR: testExcluded: /c found in runpath of ${b-a-c}/bin/main"
      "ERROR: testPrecedes: /a does not precede /a in runpath of ${b-a-c}/bin/main"
      "ERROR: testPrecedes: /a does not precede /b in runpath of ${b-a-c}/bin/main"
      "ERROR: testPrecedes: /b does not precede /b in runpath of ${b-a-c}/bin/main"
      "ERROR: testPrecedes: /c does not precede /a in runpath of ${b-a-c}/bin/main"
      "ERROR: testPrecedes: /c does not precede /b in runpath of ${b-a-c}/bin/main"
      "ERROR: testPrecedes: /c does not precede /c in runpath of ${b-a-c}/bin/main"
      "ERROR: testSucceeds: /a does not succeed /a in runpath of ${b-a-c}/bin/main"
      "ERROR: testSucceeds: /a does not succeed /c in runpath of ${b-a-c}/bin/main"
      "ERROR: testSucceeds: /b does not succeed /b in runpath of ${b-a-c}/bin/main"
      "ERROR: testSucceeds: /b does not succeed /a in runpath of ${b-a-c}/bin/main"
      "ERROR: testSucceeds: /b does not succeed /c in runpath of ${b-a-c}/bin/main"
      "ERROR: testSucceeds: /c does not succeed /c in runpath of ${b-a-c}/bin/main"
    ];
  };

  # TODO: Tests for conditional includes/excludes.
}
