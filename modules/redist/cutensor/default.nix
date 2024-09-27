{ cuda-lib, ... }:
{
  config.redists.cutensor = cuda-lib.utils.mkRedistConfig {
    hasOverrides = true;
    path = ./.;
    versionPolicy = "minor";
  };
}
