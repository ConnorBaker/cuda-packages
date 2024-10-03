{ cuda-lib, ... }:
{
  config.redists.cudss = cuda-lib.utils.mkRedistConfig {
    hasOverrides = false;
    path = ./.;
    versionPolicy = "minor";
  };
}
