{
  lib,
  replaceVarsWith,
  sourceGuard,
  stdenvNoCC,
  testers,
  writeTextFile,
}:
let
  inherit (lib.asserts) assertMsg;
  inherit (lib.strings) escapeShellArg isPath;
in
# TODO: Document and add tests.
{
  name,
  script,
  # hooks go in nativeBuildInputs so these will be nativeBuildInputs due to the dependency shift
  propagatedBuildInputs ? [ ],
  # these will be buildInputs
  depsTargetTargetPropagated ? [ ],
  replacements ? { },
  meta ? { },
  passthru ? { },
}:
assert assertMsg (isPath script) "makeSetupHook': script must be a path";
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
# Since we're producing a setup hook which will in turn be used in nativeBuildInputs,
# all of our dependency propagation is understood to be shifted by one to the right --
# that is, our propagatedBuildInputs will, when our hook is included in nativeBuildInputs,
# be added to
stdenvNoCC.mkDerivation {
  # Boilerplate
  __structuredAttrs = true;
  allowSubstitutes = false;
  preferLocalBuild = true;
  strictDeps = true;

  inherit
    name
    propagatedBuildInputs
    depsTargetTargetPropagated
    meta
    ;

  src = null;
  dontUnpack = true;

  # TODO: sourceGuard isn't found when it's made a propagatedBuildInput; why?
  # Maybe something to do with https://github.com/NixOS/nixpkgs/pull/31414?
  depsHostHostPropagated = [ sourceGuard ];

  setupHook = writeTextFile {
    name = "makeSetupHookPrime-${templatedScriptName}";
    text = ''
      sourceGuard ${escapeShellArg name} ${escapeShellArg templatedScript}
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
