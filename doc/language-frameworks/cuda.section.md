# CUDA {#cuda}

Compute Unified Device Architecture (CUDA) is a parallel computing platform and application programming interface (API) model created by NVIDIA. It's commonly used to accelerate computationally intensive problems and has been widely adopted for High Performance Computing (HPC) and Machine Learning (ML) applications.

Packages which require CUDA are typically stored in the `cudaPackages` packages sets. Nixpkgs provides a number of different CUDA package sets, each based on a different CUDA release. All of these package sets include common CUDA packages like `libcublas`, `cudnn`, `tensorrt`, and `nccl`.

## Configuring Nixpkgs for CUDA {#cuda-configuring-nixpkgs-for-cuda}

CUDA support is not enabled by default in Nixpkgs. To enable CUDA support, make sure Nixpkgs is imported with a configuration similar to the following:

```nix
{
  allowUnfreePredicate =
    let
      ensureList = x: if builtins.isList x then x else [ x ];
      cudaLicenses = {
        "CUDA EULA" = true;
        "cuDNN EULA" = true;
        "cuSPARSELt EULA" = true;
        "cuTENSOR EULA" = true;
        "NVIDIA Math Libraries EULA" = true;
        "NVidia OptiX EULA" = true;
        "NVIDIA SLA" = true;
        "TensorRT EULA" = true;
      };
      isFreeOrCudaLicense = license: license.free || cudaLicenses.${license.shortName or ""} or false;
    in
    p:
    builtins.all isFreeOrCudaLicense (ensureList p.meta.license);
  cudaCapabilities = [ ... ];
  cudaForwardCompat = true;
  cudaSupport = true;
}
```

The majority of CUDA packages are unfree, so either `allowUnfreePredicate` or `allowUnfree` should be set.

The `cudaSupport` configuration option is used by packages to conditionally enable CUDA-specific functionality. This configuration option is commonly used by packages which can be built with or without CUDA support.

The `cudaCapabilities` configuration option specifies a list of CUDA capabilities. Packages may use this option to control device code generation to take advantage of architecture-specific functionality, speed up compile times by producing less device code, or slim package closures. As an example, one can build for Ada Lovelace GPUs with `cudaCapabilities = [ "8.9" ];`. If `cudaCapabilities` is not provided, the default value is calculated per-package set, derived from a list of GPUs supported by that version of CUDA. Please consult [supported GPUs](https://en.wikipedia.org/wiki/CUDA#GPUs_supported) for specific cards. Library maintainers should consult [NVCC Docs](https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/) and its release notes.

The `cudaForwardCompat` boolean configuration option determines whether PTX support for future hardware is enabled.

## Configuring CUDA package sets {#cuda-configuring-cuda-package-sets}

CUDA package sets are created by `callPackage` and provided explicit `manifests` and `fixups` attributes.

::: {.important}
The `manifests` and `fixups` attribute sets are not part of the CUDA package set fixed-point, but are instead provided as explicit arguments to `callPackage` in the construction of the package set. As such, for changes to `manifests` or `fixups` to take effect, they should be modified through the package set's `override` attribute.
:::

The `manifests` attribute contains the JSON manifest files to use for a particular package set, while the `fixups` attribute set is a mapping from package name to a `callPackage`-able expression which will be provided to `overrideAttrs` on the result of `redist-builder`. Changing the version of a redistributable (like cuDNN) involves calling `override` on the relevant CUDA package set and overriding the corresponding entry in the `manifests` and `fixups` arguments provided to `callPackage`.

::: {.important}
The fixup is chosen by `pname`, so packages with multiple versions (e.g., `cudnn`, `cudnn_8_9`, etc.) all share a single fixup function (i.e., `fixups/cudnn.nix`).
:::

As an example, you can change the version of a redistributable in the CUDA package set with this overlay:

```nix
final: prev: {
  cudaPackages = prev.cudaPackages.override (prevAttrs: {
    manifests = prevAttrs.manifests // {
      cudnn = final.lib.importJSON <path-to-json-manifest>;
    };
  });
}
```

## Extending CUDA package sets {#cuda-extending-cuda-package-sets}

CUDA package sets are scopes, so they provide the usual `overrideScope` attribute for overriding package attributes (see the note about `manifests` and `fixups` in [Configuring CUDA package sets](#cuda-configuring-cuda-package-sets)).

Inspired by `pythonPackagesExtensions`, the `cudaPackagesExtensions` attribute is a list of extensions applied to every version of the CUDA package set, allowing modification of all versions of the CUDA package set without having to know what they are or invoke them explicitly. As an example, disabling `cuda_compat` across all CUDA package sets can be accomplished with this overlay:

```nix
_: prev: {
  cudaPackagesExtensions = prev.cudaPackagesExtensions ++ [ (_: _: { cuda_compat = null; }) ];
}
```

## Creating CUDA package sets {#cuda-creating-cuda-package-sets}

CUDA package sets are created with `callPackage`. To ease creation of new CUDA package sets, the top-level `cudaLib` attribute provides the path to the root of the `cuda-modules` directory as `cudaLib.data.cudaPackagesPath`.

As an example, you can create a new CUDA package set with a different version of CUDA, re-using the `fixups` and `manifests` the default CUDA package set uses, with this overlay:

```nix
final: _: {
  cudaPackages_custom = final.callPackage final.cudaLib.data.cudaPackagesPath {
    inherit (final.cudaPackages) fixups;
    manifests = final.cudaPackages.manifests // {
      cuda = final.lib.importJSON <path-to-json-manifest>;
    };
  };
}
```

## Using cudaPackages {#cuda-using-cudapackages}

::: {.important}
A non-trivial amount of CUDA package discoverability and usability relies on the various setup hooks used by a CUDA package set. As a result, users will likely encounter issues trying to perform builds within a `devShell` without manually invoking phases.
:::

Nixpkgs makes CUDA package sets available under a number of attributes. While versioned package sets are available (e.g., `cudaPackages_12_2`), it is recommended to use the unversioned `cudaPackages` attribute, which is an alias to the latest version, as versioned attributes are periodically removed.

To use one or more CUDA packages in an expression, give the expression a `cudaPackages` parameter, and in case CUDA support is optional, add a `config` and `cudaSupport` parameter:

```nix
{
  config,
  cudaSupport ? config.cudaSupport,
  cudaPackages,
  stdenv,
}:
stdenv.mkDerivation { ... }
```

In your package's derivation arguments, it is _strongly_ recommended the following are set:

```nix
{
  __structuredAttrs = true;
  strictDeps = true;
}
```

These settings ensure that the CUDA setup hooks function as intended.

When using `callPackage`, you can choose to pass in a different variant, e.g. when a package requires a specific version of CUDA:

```nix
{
  mypkg = callPackage { cudaPackages = cudaPackages_12_2; };
}
```

### Using cudaPackages.pkgs {#cuda-using-cudapackages-pkgs}

Each CUDA package set has a `pkgs` attribute, which is an instance of Nixpkgs where enclosing CUDA package set is made the default CUDA package set. This was done primarily to avoid package set leakage, wherein a member of a non-default CUDA package set has a (potentially transitive) dependency on a member of the default CUDA package set.

:::{.note}
Package set leakage is a common problem in Nixpkgs, and is not limited to CUDA package sets.
:::

As an added benefit of `pkgs` being configured this way, building a package with a non-default version of CUDA is as simple as accessing an attribute. As an example, `cudaPackages_12_8.pkgs.opencv` provides OpenCV built against CUDA 12.8.

### Choosing a stdenv {#cuda-choosing-a-stdenv}

NVCC has a supported range of host compilers (GCC and Clang), which it wraps presents itself as when doing C-preprocessing/C++ templating. NVCC implements its own functionality for CUDA source files, but otherwise delegates to the host compiler. Generally, NVCC is very tightly coupled to GCC/Clang, e.g. the NVCC C/C++ pre-processor may not be able to parse or use `libc`/`libcpp` headers from newer host compilers when they use new language functionality.

NVCC is wrapped and includes a setup hook to ensure it has a supported host compiler available and that the host compiler links against the same `glibc`/`glibcxx` the rest of the Nixpkgs does (using those provided by `pkgs.stdenv`). As such, There are two choices of `stdenv` when packaging a CUDA application: `pkgs.stdenv` and `cudaPackages.cudaStdenv`.

The benefit of using `pkgs.stdenv` is that adding CUDA support to a package is as simple as adding the relevant members of `cudaPackages` to `nativeBuildInputs` and `buildInputs` conditioned on `config.cudaSupport`. However, the largest (known) drawback is that using `pkgs.stdenv` breaks Link Time Optimization (LTO) because the host compiler used by NVCC is not the same as the host compiler used by `pkgs.stdenv` and the linker cannot work across object files produced by different compilers or compiler versions.

The benefit of using `cudaPackages.cudaStdenv` then is that it allows for LTO to work; the drawback is that adding CUDA support is much more invasive given the need for logic in the package expression which selects a `stdenv` based on `config.cudaSupport`. Such conditional logic is usually called the `effectiveStdenv` pattern:

```nix
{
  config,
  cudaSupport ? config.cudaSupport,
  cudaPackages,
  stdenv,
}@inputs:
let
  effectiveStdenv = if cudaSupport then cudaPackages.cudaStdenv else inputs.stdenv;
  stdenv = builtins.throw "please use effectiveStdenv";
in
effectiveStdenv.mkDerivation { ... }
```

### The dangers of symlinkJoin {#cuda-the-dangers-of-symlinkjoin}

A number of build systems (recent versions of CMake excluded) expect a monolithic CUDA installation and use paths relative to that root to resolve dependencies on different CUDA components. Such expectations are invalidated when building with Nixpkgs, as our CUDA installations are split into multiple directories -- generally per-component and per-output type (e.g., `lib`, `bin`, `include`, etc.).

In situations where patching a project's build system is infeasible, `symlinkJoin` can be used to create a monolithic CUDA installation. However, this is not without its own pitfalls: since `symlinkJoin` does not clobber existing files, a naive `symlinkJoin` will not produce the desired result, as only the first observed file in `nix-support` will be included in the resulting `nix-support` directory.

Generally, there are three types of files CUDA packages place in `nix-support` directories:

1. `setup-hook` files, which are used to set up the environment for the package.
2. `include-in-cudatoolkit-root` files, which are used to mark the output for processing by `cudaHook`
3. Dependency files, like `propagated-build-inputs` or `propagated-host-host-deps`, which are produced during `fixupPhase`

The `setup-hook` files cannot be concatenated, as they include `return` statements to guard against multiple invocations. Instead, they should be copied to the `nix-support` directory of the `symlinkJoin` output under different names and sourced, one by one, in a new `setup-hook`.

The `include-in-cudatoolkit-root` can be left unmodified in the `symlinkJoin` output, as it is an empty file, so they are all identical.

Finally, the corresponding dependency files from each path should have references to other paths in the `symlinkJoin` replaced with the `symlinkJoin` output, be deduplicated, and concatenated with a space.

:::{.important}
The concatenation of dependency files with a space is based on the implementation of `recordPropagatedDependencies` in `stdenv`'s `setup.sh` using `printWords`. If this implementation changes, the concatenation method will need to be updated as well.
:::

### Common build system patterns {#cuda-common-build-system-patterns}

CUDA software is packaged using a variety of build systems -- often, a combination of them! Each build system has its own peculiarities when it comes to CUDA support, so this section will never be exhaustive. Instead, we hope to provide a few common patterns and pitfalls to watch out for.

Common to all build systems, producing CUDA device code typically requires `cuda_nvcc`. As a compiler, it should typically only ever be added to `nativeBuildInputs`. However, in the rare case that a package needs to compile CUDA device code at runtime, it should be added to `buildInputs` as well. The CUDA runtime library, `cuda_cudart`, is usually added to `buildInputs` as it is required for any CUDA application to run.

```nix
{
  cudaPackages,
  stdenv,
}:
stdenv.mkDerivation {
  __structuredAttrs = true;
  strictDeps = true;
  nativeBuildInputs = [ cudaPackages.cuda_nvcc ];
  buildInputs = [ cudaPackages.cuda_cudart ];
}
```

In every case, ensure projects do not hard-code things like CUDA installation directories or device code to generate. If they do, you will need to patch the project to use the corresponding values provided by the CUDA package set. Since these values are typically created by the project author, the names are not standardized or documented (as they are considered a build system detail). As such, you will likely need to read the project's documentation and source code to determine what values to patch.

#### Bazel {#cuda-bazel}

Bazel rules for CUDA only [recently gained support for using redistributable packages](https://github.com/bazel-contrib/rules_cuda/pull/286). In addition, those rules do not support splayed CUDA installations. As a result, building CUDA software with Bazel will likely require using `symlinkJoin` to create a monolithic CUDA installation -- make sure to read [The dangers of symlinkJoin](#cuda-the-dangers-of-symlinkjoin)!

#### CMake {#cuda-cmake}

Support for CMake is provided by the `cudaHook` and `nvccHook` setup hooks in `cudaPackages`. The `cudaHook` is added to the `propagatedBuildInputs` of all packages constructed by `redist-builder` (the majority of the package set) and `nvccHook` is added to the `propagatedBuildInputs` of `cuda_nvcc`. As such, adding members of `cudaPackages` to `nativeBuildInputs` and `buildInputs` will automatically add the relevant setup hooks to the package.

The CUDA NVCC compiler requires flags to determine which hardware you want to target for in terms of SASS (real hardware) or PTX (JIT kernels). Given CMake has standardized the format for these flags, we provide a utility function:

```nix
{
  cmake,
  cudaPackages,
  lib,
  stdenv,
}:
stdenv.mkDerivation {
  __structuredAttrs = true;
  strictDeps = true;
  nativeBuildInputs = [
    cmake
    cudaPackages.cuda_nvcc
  ];
  buildInputs = [ cudaPackages.cuda_cudart ];
  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" cudaPackages.flags.cmakeCudaArchitecturesString)
  ];
}
```

## Using pkgsCuda {#cuda-using-pkgscuda}

The `pkgsCuda` attribute set maps CUDA architectures (e.g., `sm_89` for Ada Lovelace or `sm_90a` for architecture-specific Hopper) to Nixpkgs instances configured to support exactly that architecture. As an example, `pkgsCuda.sm_89` is a Nixpkgs instance extending `pkgs` and setting the following values in `config`:

```nix
{
  cudaSupport = true;
  cudaCapabilities = [ "8.9" ];
  cudaForwardCompat = false;
}
```

:::{.note}
In `pkgsCuda`, the `cudaForwardCompat` option is set to `false` because exactly one CUDA architecture should be supported by the attached instance of Nixpkgs. Furthermore, some architectures, including architecture-specific feature sets like `sm_90a`, cannot be built with forward compatibility.
:::

:::{.important}
Not every version of CUDA supports every architecture!

To illustrate: support for Blackwell (e.g., `sm_100`) was only added in CUDA 12.8. Assume our Nixpkgs' default CUDA package set is for CUDA 12.6. Then the Nixpkgs instance available through `pkgsCuda.sm_100` is useless, since packages like `pkgsCuda.sm_100.opencv` and `pkgsCuda.sm_100.python3Packages.torch` will try to generate code for `sm_100`, an architecture unknown to CUDA 12.6. In such a case, you should use `pkgsCuda.sm_100.cudaPackages_12_8.pkgs` instead (see [Using cudaPackages.pkgs](#cuda-using-cudapackages-pkgs) for more details).
:::

The `pkgsCuda` attribute set makes it possible to access packages built for a specific architecture without needing to manually call `pkgs.extend` and supply a new `config`. As an example, `pkgsCuda.sm_89.python3Packages.torch` provides PyTorch built for Ada Lovelace GPUs.

## Using CUDA with containers {#cuda-using-cuda-with-containers}

### Running Docker or Podman containers with CUDA support {#cuda-docker-podman}

It is possible to run Docker or Podman containers with CUDA support. The recommended mechanism to perform this task is to use the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/index.html).

The NVIDIA Container Toolkit can be enabled in NixOS like follows:

```nix
{
  hardware.nvidia-container-toolkit.enable = true;
}
```

This will automatically enable a service that generates a CDI specification (located at `/var/run/cdi/nvidia-container-toolkit.json`) based on the auto-detected hardware of your machine. You can check this service by running:

```ShellSession
$ systemctl status nvidia-container-toolkit-cdi-generator.service
```

::: {.note}
Depending on what settings you had already enabled in your system, you might need to restart your machine in order for the NVIDIA Container Toolkit to generate a valid CDI specification for your machine.
:::

Once that a valid CDI specification has been generated for your machine on boot time, both Podman and Docker (> 25) will use this spec if you provide them with the `--device` flag:

```ShellSession
$ podman run --rm -it --device=nvidia.com/gpu=all ubuntu:latest nvidia-smi -L
GPU 0: NVIDIA GeForce RTX 4090 (UUID: <REDACTED>)
GPU 1: NVIDIA GeForce RTX 2080 SUPER (UUID: <REDACTED>)
```

```ShellSession
$ docker run --rm -it --device=nvidia.com/gpu=all ubuntu:latest nvidia-smi -L
GPU 0: NVIDIA GeForce RTX 4090 (UUID: <REDACTED>)
GPU 1: NVIDIA GeForce RTX 2080 SUPER (UUID: <REDACTED>)
```

You can check all the identifiers that have been generated for your auto-detected hardware by checking the contents of the `/var/run/cdi/nvidia-container-toolkit.json` file:

```ShellSession
$ nix run nixpkgs#jq -- -r '.devices[].name' < /var/run/cdi/nvidia-container-toolkit.json
0
1
all
```

### Specifying devices to expose to the container {#cuda-specifying-devices-to-expose-to-the-container}

You can choose what devices are exposed to your containers by using the identifier on the generated CDI specification. Like follows:

```ShellSession
$ podman run --rm -it --device=nvidia.com/gpu=0 ubuntu:latest nvidia-smi -L
GPU 0: NVIDIA GeForce RTX 4090 (UUID: <REDACTED>)
```

You can repeat the `--device` argument as many times as necessary if you have multiple GPUs and you want to pick up which ones to expose to the container:

```ShellSession
$ podman run --rm -it --device=nvidia.com/gpu=0 --device=nvidia.com/gpu=1 ubuntu:latest nvidia-smi -L
GPU 0: NVIDIA GeForce RTX 4090 (UUID: <REDACTED>)
GPU 1: NVIDIA GeForce RTX 2080 SUPER (UUID: <REDACTED>)
```

::: {.note}
By default, the NVIDIA Container Toolkit will use the GPU index to identify specific devices. You can change the way to identify what devices to expose by using the `hardware.nvidia-container-toolkit.device-name-strategy` NixOS attribute.
:::

### Exposing CUDA devices with docker-compose {#cuda-exposing-cuda-devices-with-docker-compose}

It's possible to expose GPU's to a `docker-compose` environment as well. With a `docker-compose.yaml` file like follows:

```yaml
services:
  some-service:
    image: ubuntu:latest
    command: sleep infinity
    deploy:
      resources:
        reservations:
          devices:
            - driver: cdi
              device_ids:
                - nvidia.com/gpu=all
```

In the same manner, you can pick specific devices that will be exposed to the container:

```yaml
services:
  some-service:
    image: ubuntu:latest
    command: sleep infinity
    deploy:
      resources:
        reservations:
          devices:
            - driver: cdi
              device_ids:
                - nvidia.com/gpu=0
                - nvidia.com/gpu=1
```

## Frequently asked questions {#cuda-frequently-asked-questions}

### How do I package CUDA-enabled software? {#cuda-how-do-i-package-cuda-enabled-software}

TODO(@connorbaker): This belongs in a best-practices guide.

- Include recommended patterns.

### How do I build CUDA-enabled software? {#cuda-how-do-i-build-cuda-enabled-software}

TODO(@connorbaker):

- Include Nixpkgs configuration as example
- Mention tradeoffs between number of devices targeted and compile time/binary sizes
- Mention `cuda_compat` and the role it plays on Jetson devices

### How do I run CUDA-enabled software? {#cuda-how-do-i-run-cuda-enabled-software}

TODO(@connorbaker):

- Mention `nixGL`, `nix-gl-host`, and solutions to arbitrary driver runpath on host devices
- Mention `cuda_compat` and the role it plays on Jetson devices

### Why do CUDA packages have so many outputs? {#cuda-why-do-cuda-packages-have-so-many-outputs}

TODO(@connorbaker):

- Reference Nix dependency tracking
- Reference default output selection
- Mention opt-in to single components for smaller build/runtime closures

### How do I minimize my closure? {#cuda-how-do-i-minimize-my-closure}

TODO(@connorbaker): I don't have a good answer to that right now other than asking that people packaging CUDA-enabled packages become familiar with Nixpkgs' CUDA packaging; that's not a fair ask for a number of reasons, the largest being lack of documentation.

#### Minimizing build-time closure {#cuda-minimizing-build-time-closure}

TODO(@connorbaker)

#### Minimizing run-time closure {#cuda-minimizing-run-time-closure}

TODO(@connorbaker)
