{
  lib,
  libcublas,
  libcusparse,
  libnvjitlink,
}:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    (lib.getLib libcublas)
    (lib.getLib libcusparse)
    libnvjitlink
  ];

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "dev"
        "include"
        "lib"
        "static"
        "stubs"
      ];
    };
  };
}
