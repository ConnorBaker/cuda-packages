{ cudaOlder }:
prevAttrs: {
  brokenConditions = prevAttrs.brokenConditions // {
    "CUDA version is too old" = cudaOlder "12";
  };
}
