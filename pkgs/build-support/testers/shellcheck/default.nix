# Dependencies (callPackage)
{
  shellcheck,
  stdenvNoCC,
}:

# testers.shellcheck function
# Docs: doc/build-helpers/testers.chapter.md
# Tests: ./tests.nix
{ src }:
stdenvNoCC.mkDerivation {
  __structuredAttrs = true;
  strictDeps = true;
  name = "run-shellcheck";
  inherit src;
  dontUnpack = true;
  nativeBuildInputs = [ shellcheck ];
  doCheck = true;
  dontConfigure = true;
  dontBuild = true;
  checkPhase = ''
    if [[ -f $src ]]; then
      nixLog "running shellcheck on source file $src"
      shellcheck "$src"
    else
      nixLog "running shellcheck on source directory $src"
      find "$src" -type f -print0 | xargs -0 shellcheck
    fi
  '';
  installPhase = ''
    touch $out
  '';
}
