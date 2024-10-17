{
  libcublas,
  libcusolver,
  libcutensor,
}:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    libcublas
    libcusolver
    libcutensor
  ];
}
