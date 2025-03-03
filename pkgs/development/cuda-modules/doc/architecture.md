# Architecture

[Return to index.](../README.md)

TODO(@connorbaker): Describe as a flow from source to package set? Create a diagram showing how `cudaModules` and `cudaPackagesExtensions` are extension points?

## The Source

TODO(@connorbaker): Add a section to History describing how the way NVIDIA makes packages available has changed (e.g., CUDA Toolkit runfile installer to redists).

NVIDIA does not release CUDA libraries for NixOS.
Supported platforms include Ubuntu and RHEL.
However, since CUDA 11.4, NVIDIA has made available "redistributable archives" (redists).

Before CUDA 11.4, the CUDA packaging in Nixpkgs relied on the monolithic CUDA Toolkit runfile installer.
The CUDA Toolkit runfile installer is a 4+ GB self-extracting archive which installs many CUDA libraries (and optionally a driver) on the host system.
Nixpkgs would manually extract the components into a single output.
This method is error-prone, manual, and produced a single large output.

Returning to CUDA 11.4, NVIDIA publishes redists on an FTP server.
Each archive provides a single CUDA library.
Examples:

- CUDA NVCC (NVIDIA CUDA Compiler Driver)
- cuBLAS
- etc.

Providing redists in Nixpkgs allows for more fine-grained dependency tracking since closures can pull in exactly those dependencies which are required instead of the monolithic CUDA Toolkit runfile installer.
As an example, we can pull in header-only libraries like CUDA CCCL without pulling in 10 GB of other "wonderful CUDA packages".

Since CUDA 11.4, the CUDA Team (Nixpkgs CUDA Team) has pushed for migration to redists.
Redist discovery is accomplished by reading JSON manifests NVIDIA publishes on their FTP server.
The CUDA Team uses these manifests to produce JSON which we use to create derivations.
The script to accomplish this is called `cuda-redist-find-features`.

`cuda-redist-find-features` downloads and unpacks each tarball in the manifest and discovers "features".
As an example, a "feature" could be what outputs should the derivation for this package provide (lib, bin, static, ...).
This script exists partially because IFD is forbidden in Nixpkgs.
So the script produces data necessary for package set creation.

There are reasons that redists and features exist as separate manifest entities.
NVIDIA can and has changed the redist manifests contents without producing a new version of the manifest.
This is also why we vendor their redists manifests in Nixpkgs.
This allows diff'ing against NVIDIA's copies of the manifest to know when things have changed.
This reduces the feature manifest JSON that is checked into Nixpkgs when we require the redist manifest also exist untouched in tree.
The union of these two manifests is used to CUDA package sets.

The Nix expression that creates CUDA package sets reads NVIDIA's redist manifests and our "feature" manifests, and adds redist packages to the CUDA package set.

## Meeting design goals

TODO(@ConnorBaker): Since the removal of [Summary of changes](#summary-of-changes), this doesn't make sense.

As described in [Design Goals](./design-goals.md), the design goals of the current version of Nixpkgs' CUDA packaging are a direct response to the pains experienced working with the previous version.

From the [Summary of changes](#summary-of-changes), we can see we have addressed the shortcomings of the previous version:

1. Extensible package sets and packages
   - `cudaPackagesExtensions` allows adding/modifying packages across all versions of CUDA package sets.
   - `cudaModules` allows changing versions of packages within a CUDA package set or adding new CUDA package sets (e.g. new CUDA releases).
   - `cudaLib` exposes generic utilities to make extensions easier.
2. Hermetic package sets
   - In each `cudaPackages_X_Y`, `pkgs` is redefined such that `pkgs.cudaPackages = cudaPackages_X_Y` ensuring `callPackage`-provided arguments use the current versioned CUDA package set being constructed and not the default CUDA package set.
3. Support for version constraints
   - Through the module system's priority system and merging strategies, we can implement version selection functionality for each package set and can warn or assert version constraints are satisfied.
