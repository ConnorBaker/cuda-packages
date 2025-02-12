{ lib }:
let
  cudaLib = lib.fixedPoints.makeExtensible (
    final:
    let
      callLibs =
        file:
        import file {
          inherit lib;
          cudaLib = final;
        };
    in
    {
      data = import ./data.nix;
      types = callLibs ./types.nix;
      utils = callLibs ./utils.nix;
    }
  );
in
cudaLib
