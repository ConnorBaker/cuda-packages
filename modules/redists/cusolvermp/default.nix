{ cuda-lib, ... }:
{
  config.redists.cusolvermp = cuda-lib.utils.mkRedistConfig {
    hasOverrides = true;
    path = ./.;
  };
}
