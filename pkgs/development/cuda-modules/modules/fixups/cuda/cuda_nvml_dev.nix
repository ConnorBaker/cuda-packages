{ lib }:
finalAttrs: prevAttrs: {
  # TODO(@connorbaker): Add a setup hook to the outputStubs output to automatically replace rpath entries
  # containing the stubs output with the driver link.

  allowFHSReferences = true;

  # Include the stubs output since it provides libnvidia-ml.so.
  propagatedBuildOutputs = prevAttrs.propagatedBuildOutputs or [ ] ++ [ "stubs" ];

  # TODO: Some programs try to link against libnvidia-ml.so.1, so make an alias.
  # Not sure about the version number though!
  postInstall =
    prevAttrs.postInstall or ""
    + lib.optionalString (lib.elem "stubs" finalAttrs.outputs) ''
      pushd "''${!outputStubs:?}/lib/stubs" >/dev/null
      if [[ -f libnvidia-ml.so && ! -f libnvidia-ml.so.1 ]]; then
        nixLog "creating versioned symlink for libnvidia-ml.so stub"
        ln -sr libnvidia-ml.so libnvidia-ml.so.1
      fi
      if [[ -f libnvidia-ml.a && ! -f libnvidia-ml.a.1 ]]; then
        nixLog "creating versioned symlink for libnvidia-ml.a stub"
        ln -sr libnvidia-ml.a libnvidia-ml.a.1
      fi
      nixLog "creating symlinks for stubs in lib directory"
      ln -srt "''${!outputStubs:?}/lib/" *.so *.so.*
      popd >/dev/null
    '';

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "dev"
        "include"
        "lib"
        "stubs"
      ];
    };
  };
}
