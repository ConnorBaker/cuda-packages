_: prevAttrs: {
  # Everything is nested under the nvvm directory.
  prePatch = prevAttrs.prePatch or "" + ''
    nixLog "un-nesting top-level $PWD/nvvm directory"
    mv -v "$PWD/nvvm"/* "$PWD/"
    nixLog "removing empty $PWD/nvvm directory"
    rmdir -v "$PWD/nvvm"
  '';
  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
      ];
    };
  };
}
