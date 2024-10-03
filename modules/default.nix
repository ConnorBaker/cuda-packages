{
  config,
  nixpkgs,
  system,
  ...
}:
let
  # Create pkgs
  pkgs = import nixpkgs {
    inherit system;
    config = {
      allowUnfree = true;
      cudaSupport = true;
      cudaCapabilities = config.cuda.capabilities;
      cudaForwardCompat = config.cuda.forwardCompat;
      cudaHostCompiler = config.cuda.hostCompiler;
    };
  };

  # Create our lib
  inherit (pkgs) lib;

  # Create our cuda-lib
  cuda-lib = import ../cuda-lib { inherit lib; };

  inherit (lib.types) bool enum;
  inherit (cuda-lib.utils) mkOptions;
in
{
  imports = [
    ./data
    ./redists
    ./package-sets.nix
  ];

  config._module.args = {
    inherit cuda-lib lib pkgs;
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
