{
  lib,
  replaceVarsWith,
  sourceGuard,
  stdenvNoCC,
  testers,
  writeTextFile,
}:
# TODO: Document and add tests.
# Docs in doc/build-helpers/special/makesetuphook.section.md
# See https://nixos.org/manual/nixpkgs/unstable/#sec-pkgs.makeSetupHook
lib.makeOverridable (
  {
    name,
    script,
    scriptNativeBuildInputs ? [ ],
    scriptBuildInputs ? [ ],
    replacements ? { },
    passthru ? { },
    meta ? { },
  }:
  # NOTE: To enforce isolation, interpolating the path in `script` causes Nix to copy the file to its own store path,
  # containing nothing else.
  assert lib.assertMsg (lib.isPath script) "makeSetupHook': script must be a path";
  let
    templatedScriptName = if replacements == { } then name else "templated-${name}";
    templatedScript =
      if replacements == { } then
        "${script}"
      else
        replaceVarsWith {
          # Boilerplate
          __structuredAttrs = true;
          strictDeps = true;

          name = templatedScriptName;
          src = "${script}";
          inherit replacements;
        };
  in
  stdenvNoCC.mkDerivation {
    # Boilerplate
    __structuredAttrs = true;
    allowSubstitutes = false;
    preferLocalBuild = true;
    strictDeps = true;

    inherit name meta;

    src = null;
    dontUnpack = true;

    # Perhaps due to the order in which Nix loads dependencies (current node, then dependencies), we need to add sourceGuard
    # as a dependency in with a slightly earlier dependency offset.
    # Adding sourceGuard to `propagatedBuildInputs` causes our `setupHook` to fail to run with a `sourceGuard: command not found`
    # error.
    # See https://github.com/NixOS/nixpkgs/pull/31414.
    depsHostHostPropagated = [ sourceGuard ];

    # Since we're producing a setup hook which will be used in nativeBuildInputs, all of our dependency propagation is
    # understood to be shifted by one to the right -- that is, the script's nativeBuildInputs corresponds to this
    # derivation's propagatedBuildInputs, and the script's buildInputs corresponds to this derivation's
    # depsTargetTargetPropagated.
    propagatedBuildInputs = scriptNativeBuildInputs;
    depsTargetTargetPropagated = scriptBuildInputs;

    setupHook = writeTextFile {
      name = "sourceGuard-${templatedScriptName}";
      text = ''
        sourceGuard ${lib.escapeShellArg name} ${lib.escapeShellArg templatedScript}
      '';
      derivationArgs = {
        # Boilerplate
        __structuredAttrs = true;
        strictDeps = true;
      };
    };

    passthru = passthru // {
      tests = passthru.tests or { } // {
        shellcheck = testers.shellcheck { src = templatedScript; };
        shfmt = testers.shfmt { src = templatedScript; };
      };
    };
  }
)
