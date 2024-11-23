{ lib }:
let
  inherit (lib.lists) elem;
  inherit (lib.strings) optionalString;
in
finalAttrs: prevAttrs: {
  allowFHSReferences = true;

  # Include the stubs output since it provides libnvidia-ml.so.
  propagatedBuildOutputs = prevAttrs.propagatedBuildOutputs ++ [ "stubs" ];

  # TODO: Some programs try to link against libnvidia-ml.so.1, so make an alias.
  # Not sure about the version number though!
  # NOTE: Add symlinks inside $stubs/lib so autoPatchelfHook can find them -- it doesn't recurse into subdirectories.
  postInstall =
    prevAttrs.postInstall or ""
    + optionalString (elem "stubs" finalAttrs.outputs) ''
      pushd "$stubs/lib/stubs"
      [[ -f libnvidia-ml.so && ! -f libnvidia-ml.so.1 ]] && ln -sr libnvidia-ml.so libnvidia-ml.so.1
      [[ -f libnvidia-ml.a && ! -f libnvidia-ml.a.1 ]] && ln -sr libnvidia-ml.a libnvidia-ml.a.1
      ln -srt "$stubs/lib/" *.so *.so.*
      popd
    '';
}
