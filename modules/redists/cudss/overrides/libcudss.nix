{
  cudaAtLeast,
  lib,
  mpi,
  nccl,
}:
let
  inherit (lib.lists) optionals;
in
prevAttrs: {
  buildInputs =
    prevAttrs.buildInputs or [ ]
    # TODO(@connorbaker): Are these required for 11.8?
    ++ optionals (cudaAtLeast "12.6") [
      mpi
      nccl
    ];
}
