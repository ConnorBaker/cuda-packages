{ cuda-lib, ... }:
{
  config.redists.nvjpeg2000 = cuda-lib.utils.mkRedistConfig {
    hasOverrides = false;
    path = ./.;
  };
}
