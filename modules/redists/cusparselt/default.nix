{ cuda-lib, ... }:
{
  config.redists.cusparselt = cuda-lib.utils.mkRedistConfig {
    hasOverrides = false;
    path = ./.;
    versionPolicy = "minor";
  };
}
