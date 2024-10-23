{ cuda-lib, ... }:
{
  config.redists.tensorrt = cuda-lib.utils.mkRedistConfig {
    hasOverrides = true;
    path = ./.;
  };
}
