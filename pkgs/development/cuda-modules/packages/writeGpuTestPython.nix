{
  lib,
  runCommand,
  python3Packages,
  makeWrapper,
}:
let
  inherit (builtins) isFunction all;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets) removeAttrs;
  inherit (lib.lists) optionals;
  inherit (lib.meta) getExe;
  inherit (lib.strings) getName;
in
{
  feature ? "cuda",
  name ? if feature == null then "cpu" else feature,
  libraries ? [ ], # [PythonPackage] | (PackageSet -> [PythonPackage])
  ...
}@args:

let
  librariesFun = if isFunction libraries then libraries else (_: libraries);
in

assert assertMsg (
  isFunction libraries || all python3Packages.hasPythonModule libraries
) "writeGpuTestPython was passed `libraries` from the wrong python release";

content:

let
  interpreter = python3Packages.python.withPackages librariesFun;
  tester =
    runCommand "tester-${name}"
      (
        removeAttrs args [
          "libraries"
          "name"
        ]
        // {
          inherit content;
          nativeBuildInputs = args.nativeBuildInputs or [ ] ++ [ makeWrapper ];
          passAsFile = args.passAsFile or [ ] ++ [ "content" ];
        }
      )
      ''
        mkdir -p "$out"/bin
        cat << EOF >"$out/bin/$name"
        #!${getExe interpreter}
        EOF
        cat "$contentPath" >>"$out/bin/$name"
        chmod +x "$out/bin/$name"

        if [[ -n "''${makeWrapperArgs+''${makeWrapperArgs[@]}}" ]] ; then
          wrapProgram "$out/bin/$name" ''${makeWrapperArgs[@]}
        fi
      '';
  tester' = tester.overrideAttrs {
    passthru.gpuCheck =
      runCommand "test-${name}"
        {
          nativeBuildInputs = [ tester' ];
          requiredSystemFeatures = optionals (feature != null) [ feature ];
        }
        ''
          set -e
          ${tester.meta.mainProgram or (getName tester')}
          touch $out
        '';
  };
in
tester'
