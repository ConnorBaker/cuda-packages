{ config, nixpkgs, ... }:
let
  # Create pkgs
  pkgs = import nixpkgs {
    config = {
      allowUnfree = true;
      cudaSupport = true;
      inherit (config) cudaCapabilities cudaForwardCompat;
    };
  };

  # Create our lib
  inherit (pkgs) lib;

  # Create our cuda-lib
  cuda-lib = import ../cuda-lib { inherit lib pkgs; };

  inherit (lib.types) bool;
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

  options = mkOptions {
    cudaCapabilities = {
      description = "List of hardware generations to build.";
      type = lib.types.listOf cuda-lib.types.cudaCapability;
      default = [ ];
    };
    cudaForwardCompat = {
      description = "Whether to include the forward compatibility gencode (+PTX) to support future GPU generations.";
      type = bool;
      default = false;
    };
  };
}
