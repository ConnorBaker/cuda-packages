{ cuda-lib, ... }:
{
  config.redists.cuda = cuda-lib.utils.mkRedistConfig {
    hasOverrides = true;
    path = ./.;
    versionPolicy = "minor";
  };
}
