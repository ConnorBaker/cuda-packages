{ cuda-lib, ... }:
{
  config.redists.cublasmp = cuda-lib.utils.mkRedistConfig {
    hasOverrides = true;
    path = ./.;
  };
}
