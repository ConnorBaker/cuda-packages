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
}
