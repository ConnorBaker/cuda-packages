{
  lib,
  stdenvNoCC,
  testers,
}:
# TODO: Document and add tests.
stdenvNoCC.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;
  name = "sourceGuard";
  src = null;
  dontUnpack = true;
  setupHook = ./sourceGuard.bash;
  passthru.tests = {
    shellcheck = testers.shellcheck { src = finalAttrs.finalPackage; };
    shfmt = testers.shfmt { src = finalAttrs.finalPackage; };
  };
  meta = {
    description = "Adds a source guard to a script";
    maintainers = lib.teams.cuda.members;
  };
})
