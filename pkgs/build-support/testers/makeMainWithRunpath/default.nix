{
  patchelf,
  runCommandCC,
  runCommand,
}:
let
  main =
    runCommandCC "build-main"
      {
        __structuredAttrs = true;
        strictDeps = true;
      }
      ''
        set -eu
        nixLog "Creating a small C application, main"
        echo "int main() { return 0; }" > main.c
        cc main.c -o main
        nixLog "Installing main to $out/bin"
        install -Dm755 main "$out/bin/main"
      '';
in
{ runpathEntries }:
runCommand "make-main-with-runpath"
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
  ''
