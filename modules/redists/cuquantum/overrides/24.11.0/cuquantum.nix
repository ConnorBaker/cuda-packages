{
  cuda_cudart,
  libcublas,
  libcusolver,
  libcutensor,
}:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    cuda_cudart
    libcublas
    libcusolver
    libcutensor
  ];
}
