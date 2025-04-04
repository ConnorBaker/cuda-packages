{
  libcufft,
  libcurand,
  libGLU,
  libglut,
  libglvnd,
  mesa,
}:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    libcufft
    libcurand
    libGLU
    libglut
    libglvnd
    mesa
  ];

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [ "out" ];
    };
  };
}
