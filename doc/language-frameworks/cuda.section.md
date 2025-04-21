# CUDA {#cuda}

Compute Unified Device Architecture (CUDA) is a parallel computing platform and application programming interface (API) model created by NVIDIA. It's commonly used to accelerate computationally intensive problems and has been widely adopted for High Performance Computing (HPC) and Machine Learning (ML) applications.

CUDA-only packages are stored in the `cudaPackages` packages sets. Nixpkgs provides a number of different CUDA package sets, each based on a different CUDA release. All of these package sets include common CUDA packages like `libcublas`, `cudnn`, `tensorrt`, and `nccl`.

## Configuring Nixpkgs for CUDA {#configuring-nixpkgs-for-cuda}

CUDA support is not enabled by default in Nixpkgs. To enable CUDA support, make sure Nixpkgs is imported with a configuration similar to the following:

```nix
{
  allowUnfree = true;
  cudaSupport = true;
  cudaCapabilities = [ ... ];
  cudaForwardCompat = true;
}
```

The majority of CUDA packages are unfree, so `allowUnfree` should be set to `true` in order to use them.

The `cudaSupport` configuration option is used by packages to conditionally enable CUDA-specific functionality. This configuration option is commonly used by packages which can be built with or without CUDA support.

The `cudaCapabilities` configuration option specifies a list of CUDA capabilities. Packages may use this option to control device code generation to take advantage of architecture-specific functionality, speed up compile times by producing less device code, or slim package closures. As an example, one can build for Ada Lovelace GPUs with `cudaCapabilities = [ "8.9" ];`. If `cudaCapabilities` is not provided, the default value is calculated per-package set, derived from a list of GPUs supported by that version of CUDA. Please consult [supported GPUs](https://en.wikipedia.org/wiki/CUDA#GPUs_supported) for specific cards. Library maintainers should consult [NVCC Docs](https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/) and its release notes.

The `cudaForwardCompat` boolean configuration option determines whether PTX support for future hardware is enabled.

### CUDA Package set configuration {#cuda-package-set-configuration}

CUDA package sets are scopes, so they provide the usual `overrideScope` attribute for overriding package attributes.

::: {.important}
The `manifests` and `fixups` attribute sets are not part of the CUDA package set fixed-point, but are instead provided as explicit arguments to `callPackage` in the construction of the package set. As such, for changes to `manifests` or `fixups` to take effect, they should be modified through the package set's `override` attribute.
:::

CUDA package sets are created by `callPackage` and provided explicit `manifests` and `fixups` attributes. The `manifests` attribute contains the JSON manifest files to use for a particular package set, while the `fixups` attribute set is a mapping from package name to a `callPackage`-able expression which will be provided to `overrideAttrs` on the result of `redist-builder`. Changing the version of a redistributable (like cuDNN) involves calling `override` on the relevant CUDA package set and overriding the corresponding entry in the `manifests` and `fixups` arguments provided to `callPackage`.

## Using CUDA packages {#using-cuda-packages}

::: {.important}
A non-trivial amount of CUDA package discoverability and usability relies on the various setup hooks used by a CUDA package set. As a result, users will likely encounter issues trying to perform builds within a `devShell` without manually invoking phases.
:::

Nixpkgs makes CUDA package sets available under a number of attributes. While versioned package sets are available (e.g., `cudaPackages_12_2`), it is recommended to use the unversioned `cudaPackages` attribute, which is an alias to the latest version, as versioned attributes are periodically removed.

To use one or more CUDA packages in an expression, give the expression a `cudaPackages` parameter, and in case CUDA support is optional, add a `config` and `cudaSupport` parameter:

```nix
{
  config,
  cudaSupport ? config.cudaSupport,
  cudaPackages ? { },
  ...
}:
{ }
```

When using `callPackage`, you can choose to pass in a different variant, e.g. when a package requires a specific version of CUDA:

```nix
{
  mypkg = callPackage { cudaPackages = cudaPackages_12_2; };
}
```

### Choosing a stdenv {#choosing-a-stdenv}

NVCC has a supported range of host compilers (GCC and Clang), which it wraps presents itself as when doing C-preprocessing/C++ templating. NVCC implements its own functionality for CUDA source files, but otherwise delegates to the host compiler. Generally, NVCC is very tightly coupled to GCC/Clang, e.g. the NVCC C/C++ pre-processor may not be able to parse or use `libc`/`libcpp` headers from newer host compilers when they use new language functionality.

NVCC is wrapped and includes a setup hook to ensure it has a supported host compiler available and that the host compiler links against the same `glibc`/`glibcxx` the rest of the Nixpkgs does (using those provided by `pkgs.stdenv`). As such, There are two choices of `stdenv` when packaging a CUDA application: `pkgs.stdenv` and `cudaPackages.cudaStdenv`.

The benefit of using `pkgs.stdenv` is that adding CUDA support to a package is as simple as adding the relevant members of `cudaPackages` to `nativeBuildInputs` and `buildInputs` conditioned on `config.cudaSupport`. However, the largest (known) drawback is that using `pkgs.stdenv` breaks LTO (Link Time Optimization) because the host compiler used by NVCC is not the same as the host compiler used by `pkgs.stdenv` and the linker cannot work across object files produced by different compilers or compiler versions.

The benefit of using `cudaPackages.cudaStdenv` then is that it allows for LTO to work; the drawback is that adding CUDA support is much more invasive given the need for logic in the package expression which selects a stdenv based on `config.cudaSupport`. Such conditional logic is usually called the `effectiveStdenv` pattern:

```nix
{
  config,
  cudaSupport ? config.cudaSupport,
  cudaPackages ? { },
  stdenv,
}@inputs:
let
  effectiveStdenv = if cudaSupport then cudaPackages.cudaStdenv else inputs.stdenv;
  stdenv = builtins.throw "please use effectiveStdenv";
in
effectiveStdenv.mkDerivation {}
```

### Common patterns {#common-patterns}

#### CUDA CMake patterns {#cuda-cmake-patterns}

The CUDA NVCC compiler requires flags to determine which hardware you want to target for in terms of SASS (real hardware) or PTX (JIT kernels). Given CMake has standardized the format for these flags, we provide a utility function:

```nix
{
  cudaPackages,
  lib,
}:
{
  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_CUDA_ARCHITECTURES" cudaPackages.flags.cmakeCudaArchitecturesString)
  ];
}
```

## Running Docker or Podman containers with CUDA support {#cuda-docker-podman}

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

### Specifying what devices to expose to the container {#specifying-what-devices-to-expose-to-the-container}

You can choose what devices are exposed to your containers by using the identifier on the generated CDI specification. Like follows:

```ShellSession
$ podman run --rm -it --device=nvidia.com/gpu=0 ubuntu:latest nvidia-smi -L
GPU 0: NVIDIA GeForce RTX 4090 (UUID: <REDACTED>)
```

You can repeat the `--device` argument as many times as necessary if you have multiple GPU's and you want to pick up which ones to expose to the container:

```ShellSession
$ podman run --rm -it --device=nvidia.com/gpu=0 --device=nvidia.com/gpu=1 ubuntu:latest nvidia-smi -L
GPU 0: NVIDIA GeForce RTX 4090 (UUID: <REDACTED>)
GPU 1: NVIDIA GeForce RTX 2080 SUPER (UUID: <REDACTED>)
```

::: {.note}
By default, the NVIDIA Container Toolkit will use the GPU index to identify specific devices. You can change the way to identify what devices to expose by using the `hardware.nvidia-container-toolkit.device-name-strategy` NixOS attribute.
:::

### Using docker-compose {#using-docker-compose}

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
