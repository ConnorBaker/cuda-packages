{ cuda-lib, ... }:
{
  config.redists.cudnn = cuda-lib.utils.mkRedistConfig {
    hasOverrides = true;
    path = ./.;
    versionPolicy = "patch";
  };
}
