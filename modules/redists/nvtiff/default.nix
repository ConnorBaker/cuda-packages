{ cuda-lib, ... }:
{
  config.redists.nvtiff = cuda-lib.utils.mkRedistConfig {
    hasOverrides = false;
    path = ./.;
    versionPolicy = "minor";
  };
}