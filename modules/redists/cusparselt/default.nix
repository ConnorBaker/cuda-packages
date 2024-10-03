{ cuda-lib, ... }:
{
  config.redists.cusparselt = cuda-lib.utils.mkRedistConfig {
    hasOverrides = true;
    path = ./.;
    versionPolicy = "minor";
  };
}
