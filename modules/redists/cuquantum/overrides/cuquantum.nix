{
  cuda-lib,
  lib,
  libcublas,
  libcusolver,
  libcutensor,
}:
finalAttrs: prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    libcublas
    libcusolver
    libcutensor
  ];
}
