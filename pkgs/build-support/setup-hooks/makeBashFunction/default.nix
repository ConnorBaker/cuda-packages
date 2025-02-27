{
  lib,
  replaceVarsWith,
  sourceGuard,
  stdenvNoCC,
  testers,
}:
let
  inherit (lib.asserts) assertMsg;
  inherit (lib.strings) isPath;
in
# TODO: Document and add tests.
{
  name,
  script,
  # hooks go in nativeBuildInputs so these will be nativeBuildInputs due to the dependency shift
  propagatedBuildInputs ? [ ],
  # these will be buildInputs
  depsTargetTargetPropagated ? [ ],
  meta ? { },
  passthru ? { },
}:
assert assertMsg (isPath script) "makeBashFunction: script must be a path";
let
  script' = "${script}";
in
# Since we're producing a setup hook which will in turn be used in nativeBuildInputs,
# all of our dependency propagation is understood to be shifted by one to the right --
# that is, our propagatedBuildInputs will, when our hook is included in nativeBuildInputs,
# be added to
stdenvNoCC.mkDerivation {
  __structuredAttrs = true;
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

  setupHook = replaceVarsWith {
    __structuredAttrs = true;
    strictDeps = true;
    name = "makeBashFunction-${name}";
    src = ./makeBashFunction.bash;
    replacements = {
      inherit name;
      script = script';
    };
  };
  passthru = passthru // {
    tests = passthru.tests or { } // {
      shellcheck = testers.shellcheck { src = script'; };
      shfmt = testers.shfmt { src = script'; };
    };
  };
}
