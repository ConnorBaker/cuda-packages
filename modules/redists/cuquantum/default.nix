{ cuda-lib, ... }:
{
  config.redists.cuquantum = cuda-lib.utils.mkRedistConfig {
    hasOverrides = true;
    path = ./.;
  };
}
