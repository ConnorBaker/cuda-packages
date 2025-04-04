_: prevAttrs: {
  passthru = prevAttrs.passthru or { } // {
    brokenConditions = prevAttrs.passthru.brokenConditions or { } // {
      "Package is not supported; use drivers from linuxPackages" = true;
    };

    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [ "out" ];
    };
  };
}
