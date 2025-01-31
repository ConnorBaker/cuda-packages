{
  mkCheckExpectedArrayAndMap,
  patchelf,
}:
mkCheckExpectedArrayAndMap.overrideAttrs (prevAttrs: {
  name = "mkCheckExpectedRunpath";

  nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [ patchelf ];

  buildPhase = ''
    runHook preBuild

    nixLog "Creating a small C application main"
    echo "int main() { return 0; }" > main.c
    cc main.c -o main

    runHook postBuild
  '';

  preCheckSetupScript =
    prevAttrs.preCheckSetupScript or ""
    + ''
      nixLog "Removing any existing runpath entries from main"
      patchelf --remove-rpath main

      nixLog "Adding runpath entries from valuesArr to main"
      local entry
      for entry in "''${valuesArr[@]}"; do
        nixLog "Adding rpath entry for $entry"
        patchelf --add-rpath "$entry" main
      done
      unset entry
    '';

  postCheckSetupScript =
    ''
      nixLog "populating actualArr with main's runpath entries"
      mapfile -d ':' -t actualArr < <(echo -n "$(patchelf --print-rpath main)")
    ''
    + prevAttrs.postCheckSetupScript or "";
})
