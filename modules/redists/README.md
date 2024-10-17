# redist

Each directory in this module contains information required to build or populate CUDA package sets.

Each directory should match the name of a suite of redistributable packages.

Each directory should contain a `data` and `overrides` directory.

## data

A directory containing JSON files where the file name is the version of the redistributable manifest from which the data originates.

## overrides

Within each directory are files named after the package they override. The contents of these files are functions provided to `callPackage`, and then given to the corresponding package's `overrideAttrs` attribute. They must return a function, otherwise `callPackage` will change the `override` attribute on the returned attribute set, breaking further overrides.
