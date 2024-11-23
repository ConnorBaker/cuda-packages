{
  cuda_cudart,
  cuda_cupti,
  lib,
}:
let
  inherit (lib.attrsets) getOutput;
in
prevAttrs: {
  allowFHSReferences = true;
  buildInputs = prevAttrs.buildInputs ++ [
    (getOutput "stubs" cuda_cudart)
    cuda_cupti
  ];
}
