{
  nixpkgs,
  ...
}:
let
  inherit (nixpkgs) lib;

  # Create our cuda-lib
  cuda-lib = import ../cuda-lib { inherit lib; };

  inherit (lib.types) bool enum;
  inherit (cuda-lib.utils) mkOptions;
in
{
  imports = [
    ./data
    ./overlay.nix
    ./redists
  ];

  config._module.args = {
    inherit cuda-lib lib;
  };

  options = {
    cuda = mkOptions {
      hostCompiler = {
        description = "The compiler to use with `backendStdenv`.";
        type = enum [
          "gcc"
          "clang"
        ];
        default = "gcc";
      };
      capabilities = {
        description = "List of hardware generations to build.";
        type = lib.types.listOf cuda-lib.types.cudaCapability;
        default = [ ];
      };
      forwardCompat = {
        description = "Whether to include the forward compatibility gencode (+PTX) to support future GPU generations.";
        type = bool;
        default = false;
      };
    };
  };
}
