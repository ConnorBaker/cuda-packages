# CUDA {#cuda}

Compute Unified Device Architecture (CUDA) is a parallel computing platform and
application programming interface (API) model created by NVIDIA. It's commonly used to accelerate computationally intensive problems and has been widely adopted for High Performance Computing (HPC) and Machine Learning (ML) applications.

CUDA-only packages are stored in the `cudaPackages` packages sets. Nixpkgs provides a number of different CUDA package sets, each based on a different CUDA release. All of these package sets include common CUDA packages like `libcublas`, `cudnn`, `tensorrt`, and `nccl`.

## Configuring Nixpkgs for CUDA {#configuring-nixpkgs-for-cuda}

CUDA support is not enabled by default in Nixpkgs. To enable CUDA support, make sure Nixpkgs is imported with a configuration similar to the following:

```nix
{
  allowUnfree = true;
  cudaSupport = true;
  cudaCapabilities = [ ... ];
}
```

The majority of CUDA packages are unfree, so `allowUnfree` should be set to `true` in order to use them.

The `cudaSupport` configuration option is used by packages to conditionally enable CUDA-specific functionality. This configuration option is commonly used by packages which can be built with or without CUDA support.

The `cudaCapabilities` configuration option specifies a list of CUDA capabilities. Packages may use this option to control device code generation to take advantage of architecture-specific functionality, speed up compile times by producing less device code, or slim package closures. As an example, one can build for Ada Lovelace GPUs with `cudaCapabilities = [ "8.9" ];`. If `cudaCapabilities` is not provided, the default value is calculated per-package set, derived from a list of GPUs supported by that version of CUDA. Please consult [supported GPUs](https://en.wikipedia.org/wiki/CUDA#GPUs_supported) for your specific card(s). Library maintainers should consult [NVCC Docs](https://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/) and its release notes.

The `cudaForwardCompat` boolean configuration option determines whether PTX support for future hardware is enabled.

### CUDA Package set configuration {#cuda-package-set-configuration}

CUDA package sets can be further configured through the `pkgs.cudaModules` attribute.

TODO(@connorbaker): Document the `pkgs.cudaModules` attribute and give an example.

## Using CUDA packages {#using-cuda-packages}

TODO(@connorbaker): Document how certain functionality relies on setup hooks and will not function in a `devShell` without manually invoking phases.

TODO(@connorbaker): Document `cudaStdenv` and `cuda_nvcc`.

Nixpkgs makes CUDA package sets available under a number of attributes. While versioned package sets are available (e.g., `cudaPackages_12_2`), it is recommended to use the unversioned `cudaPackages` attribute, which is an alias to the latest version, as versioned attributes are periodically removed.

To use one or more CUDA packages in an expression, give the expression a `cudaPackages` parameter, and in case CUDA support is optional, add a `config` and `cudaSupport` parameter:

```nix
{ config
, cudaSupport ? config.cudaSupport
, cudaPackages ? { }
, ...
}: {}
```

When using `callPackage`, you can choose to pass in a different variant, e.g.
when a package requires a specific version of CUDA:

```nix
{
  mypkg = callPackage { cudaPackages = cudaPackages_12_2; };
}
```

TODO(@connorbaker): Multiple versions of packages within the same package set are no longer supported.

If another version of say `cudnn` or `cutensor` is needed, you can override the
package set to make it the default. This guarantees you get a consistent package
set.

```nix
{
  mypkg = let
    cudaPackages = cudaPackages_11_5.overrideScope (final: prev: {
      cudnn = prev.cudnn_8_3;
    });
  in callPackage { inherit cudaPackages; };
}
```

The CUDA NVCC compiler requires flags to determine which hardware you
want to target for in terms of SASS (real hardware) or PTX (JIT kernels).

## Adding a new CUDA release {#adding-a-new-cuda-release}

> **WARNING**
>
> This section of the docs is still very much in progress. Feedback is welcome in GitHub Issues tagging @NixOS/cuda-maintainers or on [Matrix](https://matrix.to/#/#cuda:nixos.org).

The CUDA Toolkit is a suite of CUDA libraries and software meant to provide a development environment for CUDA-accelerated applications. Until the release of CUDA 11.4, NVIDIA had only made the CUDA Toolkit available as a multi-gigabyte runfile installer, which we provide through the [`cudaPackages.cudatoolkit`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages.cudatoolkit) attribute. From CUDA 11.4 and onwards, NVIDIA has also provided CUDA redistributables (“CUDA-redist”): individually packaged CUDA Toolkit components meant to facilitate redistribution and inclusion in downstream projects. These packages are available in the [`cudaPackages`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages) package set.

All new projects should use the CUDA redistributables available in [`cudaPackages`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages) in place of [`cudaPackages.cudatoolkit`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages.cudatoolkit), as they are much easier to maintain and update.

### Updating CUDA redistributables {#updating-cuda-redistributables}

1. Go to NVIDIA's index of CUDA redistributables: <https://developer.download.nvidia.com/compute/cuda/redist/>
2. Make a note of the new version of CUDA available.
3. Run

   ```bash
   nix run github:connorbaker/cuda-redist-find-features -- \
      download-manifests \
      --log-level DEBUG \
      --version <newest CUDA version> \
      https://developer.download.nvidia.com/compute/cuda/redist \
      ./pkgs/development/cuda-modules/cuda/manifests
   ```

   This will download a copy of the manifest for the new version of CUDA.

4. Run

   ```bash
   nix run github:connorbaker/cuda-redist-find-features -- \
      process-manifests \
      --log-level DEBUG \
      --version <newest CUDA version> \
      https://developer.download.nvidia.com/compute/cuda/redist \
      ./pkgs/development/cuda-modules/cuda/manifests
   ```

   This will generate a `redistrib_features_<newest CUDA version>.json` file in the same directory as the manifest.

5. Update the `cudaVersionMap` attribute set in `pkgs/development/cuda-modules/cuda/extension.nix`.

### Updating cuTensor {#updating-cutensor}

1. Repeat the steps present in [Updating CUDA redistributables](#updating-cuda-redistributables) with the following changes:
   - Use the index of cuTensor redistributables: <https://developer.download.nvidia.com/compute/cutensor/redist>
   - Use the newest version of cuTensor available instead of the newest version of CUDA.
   - Use `pkgs/development/cuda-modules/cutensor/manifests` instead of `pkgs/development/cuda-modules/cuda/manifests`.
   - Skip the step of updating `cudaVersionMap` in `pkgs/development/cuda-modules/cuda/extension.nix`.

### Updating supported compilers and GPUs {#updating-supported-compilers-and-gpus}

1. Update `nvcc-compatibilities.nix` in `pkgs/development/cuda-modules/` to include the newest release of NVCC, as well as any newly supported host compilers.
2. Update `gpus.nix` in `pkgs/development/cuda-modules/` to include any new GPUs supported by the new release of CUDA.

### Updating the CUDA Toolkit runfile installer {#updating-the-cuda-toolkit}

> **WARNING**
>
> While the CUDA Toolkit runfile installer is still available in Nixpkgs as the [`cudaPackages.cudatoolkit`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages.cudatoolkit) attribute, its use is not recommended and should it be considered deprecated. Please migrate to the CUDA redistributables provided by the [`cudaPackages`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages) package set.
>
> To ensure packages relying on the CUDA Toolkit runfile installer continue to build, it will continue to be updated until a migration path is available.

1. Go to NVIDIA's CUDA Toolkit runfile installer download page: <https://developer.nvidia.com/cuda-downloads>
2. Select the appropriate OS, architecture, distribution, and version, and installer type.

   - For example: Linux, x86_64, Ubuntu, 22.04, runfile (local)
   - NOTE: Typically, we use the Ubuntu runfile. It is unclear if the runfile for other distributions will work.

3. Take the link provided by the installer instructions on the webpage after selecting the installer type and get its hash by running:

   ```bash
   nix store prefetch-file --hash-type sha256 <link>
   ```

4. Update `pkgs/development/cuda-modules/cudatoolkit/releases.nix` to include the release.

### Updating the CUDA package set {#updating-the-cuda-package-set}

1. Include a new `cudaPackages_<major>_<minor>` package set in `pkgs/top-level/all-packages.nix`.

   - NOTE: Changing the default CUDA package set should occur in a separate PR, allowing time for additional testing.

2. Successfully build the closure of the new package set, updating `pkgs/development/cuda-modules/cuda/overrides.nix` as needed. Below are some common failures:

| Unable to ...  | During ...                       | Reason                                           | Solution                   | Note                                                         |
| -------------- | -------------------------------- | ------------------------------------------------ | -------------------------- | ------------------------------------------------------------ |
| Find headers   | `configurePhase` or `buildPhase` | Missing dependency on a `dev` output             | Add the missing dependency | The `dev` output typically contain the headers               |
| Find libraries | `configurePhase`                 | Missing dependency on a `dev` output             | Add the missing dependency | The `dev` output typically contain CMake configuration files |
| Find libraries | `buildPhase` or `patchelf`       | Missing dependency on a `lib` or `static` output | Add the missing dependency | The `lib` or `static` output typically contain the libraries |

In the scenario you are unable to run the resulting binary: this is arguably the most complicated as it could be any combination of the previous reasons. This type of failure typically occurs when a library attempts to load or open a library it depends on that it does not declare in its `DT_NEEDED` section. As a first step, ensure that dependencies are patched with [`autoAddDriverRunpath`](https://search.nixos.org/packages?channel=unstable&type=packages&query=autoAddDriverRunpath). Failing that, try running the application with [`nixGL`](https://github.com/guibou/nixGL) or a similar wrapper tool. If that works, it likely means that the application is attempting to load a library that is not in the `RPATH` or `RUNPATH` of the binary.

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

## TODO(@ConnorBaker): Improve packaging experience

- Ease packaging out-of-package-set CUDA applications.
  - Why does `cudaPackages` have `backendStdenv`?
    - NVCC has a supported range of host compilers (GCC and Clang).
    - NVCC wraps the host compiler and presents as it while doing C-preprocessing/C++ templating.
    - NVCC implements its own functionality for CUDA source files, but otherwise delegates to the host compiler.
    - NVCC is very tightly coupled to GCC/Clang, thus supported version constrained.
      - e.g. NVCC C/C++ pre-processor may not be able to parse or use libc/libcpp headers from newer host compilers when then use new language functionality.
    - `backendStdenv` makes sure that NVCC has supported host compiler available and that host compiler links against the same glibc/glibcxx the rest of the Nixpkgs does.
      - Ref. diamond dependency problem

## TODO(@ConnorBaker): NVCC Usage Patterns and Their Tradeoffs

1. Wrap NVCC
   - Pros
     - Compatible host compiler is visible only to NVCC.
     - No change to `stdenv` (user can just pull in `cuda_nvcc` into `nativeBuildInputs` and it just works).
     - No need for `backendStdenv`.
   - Cons
     - Breaks LTO because linker cannot work across object files produced by different compilers or compiler versions.
   - Details
     - Requires setup hook to prevent and check for NVCC host compiler leakage (e.g. host compiler's libc shows up in output through runpaths).
2. `backendStdenv`
   - Pros
     - NVCC host compiler is default for entire derivation.
     - LTO works
   - Cons
     - Requires all consumers of NVCC to know of and use `backendStdenv`.
   - Details
     - Requires overriding old `stdenv` to use compiler libs from default version of `stdenv`.
     - Requires setup hook to prevent and check for NVCC host compiler leakage (e.g. host compiler's libc shows up in output through runpaths).
