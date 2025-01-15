{
  freeglut ? null,
  libcufft,
  libcurand,
  libGLU,
  libglut ? null,
  libglvnd,
  mesa,
}:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs ++ [
    libcufft
    libcurand
    libGLU
    # TODO(@connorbaker): After we no longer support Nixpkgs pre https://github.com/NixOS/nixpkgs/pull/321800/files,
    # we can move entirely to libglut.
    (if libglut != null then libglut else freeglut)
    libglvnd
    mesa
  ];
}
