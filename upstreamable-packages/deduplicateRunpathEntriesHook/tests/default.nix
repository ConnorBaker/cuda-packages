{
  autoPatchelfHook,
  lib,
  deduplicateRunpathEntriesHook,
  patchelf,
  runCommand,
  stdenv,
  testers,
}:
let
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.strings) concatMapStringsSep optionalString;

  cApplication = stdenv.mkDerivation {
    # NOTE: Must set name!
    strictDeps = true;
    src = null;
    dontUnpack = true;
    buildPhase = ''
      runHook preBuild
      echo "int main() { return 0; }" > main.c
      cc main.c -o main
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      cp main "$out/bin/"
      runHook postInstall
    '';
  };

  mkCApplicationWithRunpathEntries' =
    cApplication:
    {
      name,
      runpathEntries ? [ ],
      postHookCheck,
      dontDeduplicateRunpathEntries ? null,
    }:
    let
      rpathModificationSteps = concatMapStringsSep "\n" (entry: ''
        nixLog "Adding rpath entry for ${entry}"
        patchelf --add-rpath "${entry}" main
      '') runpathEntries;
    in
    cApplication.overrideAttrs (
      prevAttrs:
      {
        name = name + optionalString (prevAttrs.__structuredAttrs or false) "-structuredAttrs";
        doCheck = true; # Enables installCheckPhase
        nativeBuildInputs = prevAttrs.nativeBuildInputs or [ ] ++ [
          deduplicateRunpathEntriesHook
          patchelf
        ];
        postBuild =
          prevAttrs.postBuild or ""
          # Newlines are important here to separate the commands.
          + optionalString (runpathEntries != [ ]) ''
            export ORIGINAL_RPATH="$(patchelf --print-rpath main)"
            nixLog "ORIGINAL_RPATH: $ORIGINAL_RPATH"

            ${rpathModificationSteps}

            export PRE_HOOK_RPATH="$(patchelf --print-rpath main)"
            nixLog "PRE_HOOK_RPATH: $PRE_HOOK_RPATH"
          '';
        # Disable automatic shrinking of runpaths which removes our doubling of paths since they are not used.
        dontPatchELF = true;
        installCheckPhase = ''
          runHook preInstallCheck
          export POST_HOOK_RPATH="$(patchelf --print-rpath $out/bin/main)"
          nixLog "POST_HOOK_RPATH: $POST_HOOK_RPATH"

          ${postHookCheck}

          runHook postInstallCheck
        '';
      }
      // optionalAttrs (dontDeduplicateRunpathEntries != null) {
        inherit dontDeduplicateRunpathEntries;
      }
    );

  args = {
    inherit
      autoPatchelfHook
      deduplicateRunpathEntriesHook
      cApplication
      lib
      runCommand
      stdenv
      testers
      ;

    cc-lib-dir = "${stdenv.cc.cc.lib.outPath}/lib";
    cc-libc-lib-dir = "${stdenv.cc.bintools.libc.outPath}/lib";
    mkCApplicationWithRunpathEntries = mkCApplicationWithRunpathEntries' cApplication;
  };

  args-structuredAttrs = args // {
    cApplication = cApplication.overrideAttrs { __structuredAttrs = true; };
    mkCApplicationWithRunpathEntries = mkCApplicationWithRunpathEntries' args-structuredAttrs.cApplication;
  };
in
{
  # TODO: Test properties, like the order of the runpath entries being preserved.

  # Tests for dontDeduplicateRunpathEntries option.
  dontDeduplicateRunpathEntries = import ./dontDeduplicateRunpathEntries.nix args;

  # TODO: Remove this when structuredAttrs is the default.
  dontDeduplicateRunpathEntries-structuredAttrs = import ./dontDeduplicateRunpathEntries.nix args-structuredAttrs;

  # Tests for deduplicateRunpathEntriesHookOrderCheckPhase.
  deduplicateRunpathEntriesHookOrderCheckPhase = import ./deduplicateRunpathEntriesHookOrderCheckPhase.nix args;

  # TODO: Remove this when structuredAttrs is the default.
  deduplicateRunpathEntriesHookOrderCheckPhase-structuredAttrs = import ./deduplicateRunpathEntriesHookOrderCheckPhase.nix args-structuredAttrs;

  # Tests for deduplicateRunpathEntries.
  deduplicateRunpathEntries = import ./deduplicateRunpathEntries.nix args;

  # TODO: Remove this when structuredAttrs is the default.
  deduplicateRunpathEntries-structuredAttrs = import ./deduplicateRunpathEntries.nix args-structuredAttrs;
}
