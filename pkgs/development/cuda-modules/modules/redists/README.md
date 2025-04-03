# redists

Each directory:

- contains information required to build or populate CUDA package sets
- should match the name of a suite of redistributable packages
- should contain a `mkGenericRedistBuilderArgs.nix` file and may contain `callPackage`-able files and directories to be used as overrides

## overrides

Each file or directory is `callPackage`'d and passed as an argument to the `overrideAttrs` function on the corresponding package. They must be at least binary functions to ensure `callPackage` does not add attributes to the returned value.
