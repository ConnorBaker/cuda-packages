{ cudaAtLeast, lib }:
prevAttrs: {
  prePatch =
    prevAttrs.prePatch or ""
    + lib.optionalString (cudaAtLeast "13.0") ''
      nixLog "removing top-level $PWD/include/nv directory"
      rm -rfv "$PWD/include/nv"
      nixLog "un-nesting top-level $PWD/include/cccl directory"
      mv -v "$PWD/include/cccl"/* "$PWD/include/"
      nixLog "removing empty $PWD/include/cccl directory"
      rmdir -v "$PWD/include/cccl"
    '';

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "dev"
        "include"
      ];
    };
  };
}
