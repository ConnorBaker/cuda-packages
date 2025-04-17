_: prevAttrs: {
  passthru = prevAttrs.passthru or { } // {
    brokenAssertions = prevAttrs.passthru.brokenAssertions or [ ] ++ [
      {
        message = "package is unsupported: use drivers from linuxPackages";
        assertion = false;
      }
    ];

    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [ "out" ];
    };
  };
}
