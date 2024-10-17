{ cuda-lib, ... }:
{
  config.redists.cudss = cuda-lib.utils.mkRedistConfig {
    hasOverrides = true;
    path = ./.;
    versionPolicy = "minor";
  };
}
