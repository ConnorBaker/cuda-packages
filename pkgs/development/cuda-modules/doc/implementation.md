# Implementation

[Return to index.](../README.md)

## Summary of changes

Through the Nixpkgs module system, the current implementation is able to provide these features:

- A self-documenting API to inform the creation of CUDA package sets.
- Evaluation-time checking for configuration options, providing descriptive error messages for misconfigurations.
- Support for expressing and enforcing various encodings of version constraints.

The following additions to `pkgs` were made:

- The new `cudaLib` attribute exposes the same packaging machinery (option modules, utility functions, types, etc.) Nixpkgs used to construct the CUDA package sets. Out-of-tree users can modify `cudaLib` to change the functions responsible for package set construction or re-use them to create their own.
- Inspired by `pythonPackagesExtensions`, the new `cudaPackagesExtensions` attribute is a list of extensions applied to every version ofthe CUDA package set, allowing modification of all versions of the CUDA package set without having to know what they are or invoke them explicitly.
- The new `pkgsCuda` attribute set maps real architecture to an instance of `pkgs` with CUDA support enabled and configured for only that architecture. These instances of `pkgs` provide an easy way to build CUDA applications for a specific architecture without having to worry about configuring Nixpkgs.

The following additions to each CUDA package set were made:

- The `pkgs` attribute within the CUDA package set scope is defined such that `pkgs.cudaPackages` is the enclosing CUDA package set. This change ensures `callPackage`-provided arguments received by package set members come from an instance of `pkgs` where the default CUDA package set is the enclosing CUDA package set.

TODO(@ConnorBaker): Reference terms in the glossary.
