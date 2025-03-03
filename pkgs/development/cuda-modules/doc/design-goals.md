# Design Goals

[Return to index.](../README.md)

The design goals of the current version of Nixpkgs' CUDA packaging are a direct response to the pains experienced working with the previous version:

1. Extensible package sets and packages.
2. Hermetic package sets
3. Support for version constraints.

For a summary of how these design goals were achieved, see [Architecture: Meeting design goals](./architecture.md#meeting-design-goals).

Information on the driving factors behind the design of the previous version is available in [History](./history.md).

A selection of the shortcomings of the previous version follows.

> [!IMPORTANT]
>
> These pain points are presented from the perspective of @ConnorBaker, a CUDA Maintainer and out-of-tree consumer of the CUDA package sets. As such, they are not representative of the experience of anyone who might interact with the CUDA package sets. Notable exclusions include the need to use `backendStdenv` over `stdenv` and the various difficulties enabling and selecting supported CUDA compute capabilities (`config.cudaSupport` and `config.cudaCapabilities`, respectively).

### Package sets and packages are not easily extensible

Two common use-cases require extensibility:

1. Adding new releases of CUDA libraries.
2. Adding packages to every version of the CUDA package set.

The first use-case required forking Nixpkgs and modifying the CUDA package set creation expression since the mechanisms used to produce the package sets were neither extensible nor provided as reusable functions.

The second use-case was not possible at all, as the package sets did not provide an API for adding packages to all versions of the CUDA package set. Instead, users had to know the names of all versions of the CUDA package set and extend each.

### Package sets are leaky

While this is a problem all versioned package sets share, the large closures of the CUDA package set exacerbate it.

Members of versioned package sets may rely on packages with direct or transitive dependencies on other versions of the versioned package set. This is a byproduct of the way non-members access members of the versioned package: typically the non-member package is `callPackage`'d with the unversioned (default) package set instead of the package set currently being constructed. As a result, building the dependencies of some member of a versioned package set may require building members of different version of the versioned package set.

As an example, the following illustrates a scenario where a member of a versioned package set (`cudaPackages_12_2`) depends on a package in the default CUDA package set (`cudaPackages`) because `pkgs.some_package` was `callPackage`'d with the default CUDA package set instead of the versioned package set currently being constructed (`cudaPackages_12_2`).

```plaintext
cudaPackages_12_2.whatever
  └── pkgs.some_package
      └── cudaPackages.something_else
```

### Poor support for version constraints

NVIDIA publishes support matrices for their software releases, both for individual packages and their deep-learning containers.[^1][^2][^3]

Putting aside the utility and accuracy of these support matrices, the previous version of the CUDA packaging provided little or no support for enforcing or warning about violations of version constraints.[^4]

[^1]: cuDNN 9.7.0 Support Matrix: <https://web.archive.org/web/20250303185951/https://docs.nvidia.com/deeplearning/cudnn/backend/v9.7.0/reference/support-matrix.html>.

[^2]: TensorRT 10.8.0 Support Matrix: <https://web.archive.org/web/20250303190030/https://docs.nvidia.com/deeplearning/tensorrt/latest/getting-started/support-matrix.html>.

[^3]: NVIDIA Optimized Frameworks Support Matrix: <https://web.archive.org/web/20250218032317/https://docs.nvidia.com/deeplearning/frameworks/support-matrix/index.html>.

[^4]:
    NVIDIA maintains a notice on their website absolving them of responsibility for the accuracy of the information on their site: <https://web.archive.org/web/20250218032317/https://docs.nvidia.com/deeplearning/frameworks/support-matrix/index.html#notices-header>.
    TODO(@ConnorBaker): Find example violation of version constraints.
    For example, NVIDIA Container Registry (NGC) provides containers of packages that do not match their compatibility matrices.
