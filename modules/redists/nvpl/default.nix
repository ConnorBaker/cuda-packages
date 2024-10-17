{ cuda-lib, ... }:
{
  config.redists.nvpl = cuda-lib.utils.mkRedistConfig {
    hasOverrides = false;
    path = ./.;
    versionPolicy = "minor";
  };
}
