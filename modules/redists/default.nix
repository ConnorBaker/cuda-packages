{ cuda-lib, lib, ... }:
let
  inherit (lib.options) mkOption;
in
{
  imports = [
    ./cublasmp
    ./cuda
    ./cudnn
    ./cudss
    ./cuquantum
    ./cusolvermp
    ./cusparselt
    ./cutensor
    ./nvjpeg2000
    ./nvpl
    ./nvtiff
    ./tensorrt
  ];
  options = {
    redists = mkOption {
      description = "A mapping from redist name to redistConfig";
      type = cuda-lib.types.redists;
      default = { };
    };
  };
}
