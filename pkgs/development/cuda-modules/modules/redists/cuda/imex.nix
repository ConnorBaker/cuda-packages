{ zlib }:
prevAttrs: {
  allowFHSReferences = true;
  buildInputs = prevAttrs.buildInputs or [ ] ++ [ zlib ];
}
