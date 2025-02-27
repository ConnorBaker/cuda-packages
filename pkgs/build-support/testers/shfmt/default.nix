# Dependencies (callPackage)
{
  shfmt,
  stdenvNoCC,
}:

# testers.shfmt function
# Docs: doc/build-helpers/testers.chapter.md
# Tests: ./tests.nix
{ src }:
stdenvNoCC.mkDerivation {
  __structuredAttrs = true;
  strictDeps = true;
  name = "run-shfmt";
  inherit src;
  dontUnpack = true;
  nativeBuildInputs = [ shfmt ];
  doCheck = true;
  dontConfigure = true;
  dontBuild = true;
  checkPhase = ''
    if [[ -f $src ]]; then
      nixLog "running shfmt on source file $src"
      shfmt --diff --indent 2 --simplify "$src"
    else
      nixLog "running shfmt on source directory $src"
      find "$src" -type f -print0 | xargs -0 shfmt --diff --indent 2 --simplify
    fi
  '';
  installPhase = ''
    touch "$out"
  '';
}
