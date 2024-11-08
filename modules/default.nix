{
  lib,
  ...
}:
{
  imports = [
    ./data
    ./redists
  ];

  config._module.args = {
    cuda-lib = import ../cuda-lib { inherit lib; };
  };
}
