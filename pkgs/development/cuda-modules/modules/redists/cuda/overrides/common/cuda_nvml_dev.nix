{ lib }:
let
  inherit (lib.lists) elem;
  inherit (lib.strings) optionalString;
in
finalAttrs: prevAttrs: {
  allowFHSReferences = true;

  # Include the stubs output since it provides libnvidia-ml.so.
  propagatedBuildOutputs = prevAttrs.propagatedBuildOutputs or [ ] ++ [ "stubs" ];

  # TODO: Some programs try to link against libnvidia-ml.so.1, so make an alias.
  # Not sure about the version number though!
  # NOTE: Add symlinks inside $stubs/lib so autoPatchelfHook can find them -- it doesn't recurse into subdirectories.
  postInstall =
    prevAttrs.postInstall or ""
    + optionalString (elem "stubs" finalAttrs.outputs) ''
      pushd "$stubs/lib/stubs"
      if [[ -f libnvidia-ml.so && ! -f libnvidia-ml.so.1 ]]; then
        nixLog "creating versioned symlink for libnvidia-ml.so stub"
        ln -sr libnvidia-ml.so libnvidia-ml.so.1
      fi
      if [[ -f libnvidia-ml.a && ! -f libnvidia-ml.a.1 ]]; then
        nixLog "creating versioned symlink for libnvidia-ml.a stub"
        ln -sr libnvidia-ml.a libnvidia-ml.a.1
      fi
      nixLog "creating symlinks for stubs in lib directory"
      ln -srt "$stubs/lib/" *.so *.so.*
      popd
    '';
}
