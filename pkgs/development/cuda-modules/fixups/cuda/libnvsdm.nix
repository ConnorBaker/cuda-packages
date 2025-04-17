_: prevAttrs: {
  allowFHSReferences = true;

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      # TODO(@connorbaker): Not sure this is the correct set of outputs.
      outputs = [ "out" ];
    };
  };
}
