{ cuda-lib, ... }:
{
  config.redists.nppplus = cuda-lib.utils.mkRedistConfig {
    hasOverrides = false;
    path = ./.;
  };
}
