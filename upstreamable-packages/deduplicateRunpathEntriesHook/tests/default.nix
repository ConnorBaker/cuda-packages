{
  autoPatchelfHook,
  deduplicateRunpathEntriesHook,
  mkCheckExpectedArrayAndMap,
  nixLogWithLevelAndFunctionNameHook,
  patchelf,
  stdenv,
  testers,
}:
let
  mkCheckExpectedRunpath = mkCheckExpectedArrayAndMap.override {
    setup = ''
      nixLog "Creating a small C application main"
      echo "int main() { return 0; }" > main.c
      cc main.c -o main

      nixLog "Removing any existing runpath entries from main"
      patchelf --remove-rpath main

      nixLog "Adding runpath entries from valuesArr to main"
      local entry
      for entry in "''${valuesArr[@]}"; do
        nixLog "Adding rpath entry for $entry"
        patchelf --add-rpath "$entry" main
      done
      unset entry

      nixLog "running deduplicateRunpathEntries on main"
      deduplicateRunpathEntries main

      nixLog "populating actualArr with main's runpath entries"
      mapfile -d ':' -t actualArr < <(echo -n "$(patchelf --print-rpath main)")
    '';
    extraNativeBuildInputs = [
      deduplicateRunpathEntriesHook
      patchelf
    ];
    # Disable automatic shrinking of runpaths which removes our doubling of paths since they are not used.
    derivationArgs.dontPatchELF = true;
  };

  args = {
    inherit
      autoPatchelfHook
      deduplicateRunpathEntriesHook
      mkCheckExpectedRunpath
      nixLogWithLevelAndFunctionNameHook
      stdenv
      testers
      ;
  };
in
{
  # Tests for dontDeduplicateRunpathEntries option.
  dontDeduplicateRunpathEntries = import ./dontDeduplicateRunpathEntries.nix args;

  # Tests for deduplicateRunpathEntriesHookOrderCheckPhase.
  deduplicateRunpathEntriesHookOrderCheckPhase = import ./deduplicateRunpathEntriesHookOrderCheckPhase.nix args;

  # Tests for deduplicateRunpathEntries.
  deduplicateRunpathEntries = import ./deduplicateRunpathEntries.nix args;
}
