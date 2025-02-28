{
  lib,
  stdenvNoCC,
  testers,
}:
# TODO: Document and add tests.
# Docs in doc/build-helpers/special/makesetuphook.section.md
# See https://nixos.org/manual/nixpkgs/unstable/#sec-pkgs.makeSetupHook
stdenvNoCC.mkDerivation (finalAttrs: {
  # Boilerplate
  __structuredAttrs = true;
  allowSubstitutes = false;
  preferLocalBuild = true;
  strictDeps = true;

  name = "sourceGuard";

  src = null;
  dontUnpack = true;

  # Since we're producing a setup hook which will be used in nativeBuildInputs, all of our dependency propagation is
  # understood to be shifted by one to the right -- that is, the script's nativeBuildInputs corresponds to this
  # derivation's propagatedBuildInputs, and the script's buildInputs corresponds to this derivation's
  # depsTargetTargetPropagated.
  # propagatedBuildInputs = scriptNativeBuildInputs;
  # depsTargetTargetPropagated = scriptBuildInputs;

  setupHook = "${./sourceGuard.bash}";

  passthru.tests = lib.recurseIntoAttrs {
    shellcheck = testers.shellcheck { src = finalAttrs.setupHook; };
    shfmt = testers.shfmt { src = finalAttrs.setupHook; };
  };

  meta = {
    description = "Computes the difference of two arrays";
    maintainers = [ lib.maintainers.connorbaker ];
  };
})
