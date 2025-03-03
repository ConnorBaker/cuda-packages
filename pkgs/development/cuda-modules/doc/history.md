# History

[Return to index.](../README.md)

TODO(@ConnorBaker): Replace occurrences of first-person with my handle to make clear authorship/point of view is not representative of the CUDA Maintainers team or Nixpkgs as a whole.

## On 24.05 and dependency handling in Nix and Nixpkgs

The CUDA redistributable tarballs NVIDIA publishes had been available since the CUDA 11.4 release and the CUDA Maintainers (myself included) had tried to make efforts to move packages over to them instead of the monolithic runfile installer.[^1]
Moving a package from the runfile installer to redistributable packages brought an immediate reduction in closure size, just by virtue of including fewer packages.
However, the implementation of redistributable packaging had problems, the largest being the organization of the package outputs: static libraries often ended up getting propagated and stuck in the runtime closure of various packages!

A lot of the way CUDA packaging in 24.05 was structured was a direct result of the work I had done for PDT Partners (see [here](https://discourse.nixos.org/t/cuda-team-roadmap-and-call-for-sponsors/29495)).
They were primarily concerned with closure size of PyTorch and a few other libraries and so the work that I did was focused on making dependencies explicit -- that meant moving from the monolithic CUDA Toolkit runfile installer (currently named [`cudatoolkit-legacy-runfile`](https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/pkgs/top-level/cuda-packages.nix#L75)) to specific components of each redistributable tarball NVIDIA publishes (like header files or static libraries).[^2]

A brief digression; some arcana for Nix/Nixpkgs:

- Package outputs are expected to be binary-first (TODO: REFERENCE).
  In other words, the first output (`outputs` is a list so order matters) should be the one which contains executables.
  As an example, if your program has binaries and a library for others to use, you should have the outputs `[ "bin" "out" ]` where `bin` contains your binaries and `out` contains your libraries.
  On the other hand, if you had only libraries, your outputs should be `[ "out" ]`, where `out` contains your libraries.
- NixOS/Nixpkgs are source-first distributions/repositories and have strong preference for dynamic linking (to enable re-use of libraries in the store), so packages typically either reduce build times by disabling production of a static library or remove them to reduce closure sizes.
- The [multiple outputs setup hook](https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/pkgs/build-support/setup-hooks/multiple-outputs.sh) is used by [`stdenv.mkDerivation`](https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/pkgs/stdenv/generic/default.nix#L79) to enable multiple outputs and make the `dev` output, if present, depend on the `out` output.
  Since the multiple outputs setup hook doesn't have the notion of a `static` output, neither does Nixpkgs.
  As a result, if a package produces static libraries, they are either left in the build directory (and so not available in an output) or installed in the library output by the build system.
  Some package maintainers choose to move static libraries to a `dev` or `static` output, but they must do so manually.
- NixOS/Nixpkgs (and other distributions, like Ubuntu) typically have developer variants of each package (Nixpkgs has a `dev` output while Ubuntu uses a `-dev` suffix on the package name) which include header files, static libraries, and other things developers might need.
  By splitting a the components of a package into different packages, they enforce a separation of concerns and create a better user experience for a target audience of users.
  Developers, on the other hand, have to know to install the developer variant.
- [`stdenv.mkDerivation`](https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/pkgs/stdenv/generic/make-derivation.nix#L301-L328) will select the `dev` output for each package provided in one of the dependency arrays if the output is not explicitly provided.
  While this may be surprising, it is a sensible behavior for a package repository, because packages put developer-specific files in the `dev` output, and the `dev` output has a dependency on the `out` output (due to the multiple outputs setup hook), so a superset of components provided are brought into the build environment.
- Nix scans each derivation's outputs for references to store paths to inform construction of the runtime closure.
  As a result, if a derivation brought into scope is wholly unused, it is dropped from the runtime closure.

Some more context, this time for CUDA packaging:

- Downstream consumers of CUDA may require static libraries, so we cannot uniformly remove them from redistributable tarballs.
  As an example, CMake's compiler detection phase run as part of `cmake configure` requires the presence of certain static CUDA libraries.
- Unlike static libraries produced by most other packages in Nixpkgs, CUDA static libraries tend to be massive due to the amount of device code and number of function specializations each provide.
  It's not uncommon for them to approach or pass 1 GB in size, so we must be careful which output we place them in.
- CMake support for CUDA is relatively new and established ecosystems like OpenCV, ONNX, and PyTorch are either unable to make use of new CMake functionality due to backwards-compatibility requirements various forces demand of them or do not have the bandwidth to perform such a migration.
  As a result, each ecosystem is a special kind of (CMake) hell with wildly different approaches to finding, using, and enforcing invariants on CUDA packages.
  For example, some projects require that all CUDA packages are installed in a single directory, while others are built in such a way that some packages must exist in different directories.
- Any changes made need to avoid widespread breakage given the limited bandwidth of the CUDA Maintainers team and availability of package maintainers, because it can take a long time to resolve them.
  CUDA-enabled packages tend to have some of the most convoluted, custom, and difficult to maintain build systems across Nixpkgs, and the number of developers able to contribute to or maintain such packaging either upstream or within Nixpkgs is vanishingly small.
  Making things evne more difficult: CUDA support is disabled by default, is not built by Hydra, and does not benefit from Nixpkgs' CI tooling or checks.
  Additionally, CUDA-enabled packages are frequently broken by seemingly unrelated PRs because contributors either don't know how to check, don't have the hardware to check, or don't care to check functionality.
  Sadly, even if contributors did want to verify functionality, most packages are missing CUDA-enabled test suites and a great deal of other tooling and infrastructure which would be required to avoid a massive manual effort on the package maintainer's part to enable such verification.

CUDA redistributables are materially different compared to the majority of Nixpkgs in terms of availability (binary only), license (unfree), and size (big).
As a result, a number of the decisions made in construction of `stdenv`'s setup hooks and the setting of defaults don't handle our use case well.

To slim down closure size, the approach that I (Connor) took was to split every package into distinct components and outputs (header files in the `include` output, binaries in the `bin` output, dynamic libraries in the `lib` output, static libraries in the `static` output, etc.) and make the `out` output a `symlinkJoin` of the others.
This required that I change some values used by the multiple outputs setup hook:

- Setting [`propagatedBuildOutputs = false;`](https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/pkgs/development/cuda-modules/generic-builders/manifest.nix#L316-L320) allowed me to prevent the multiple outputs setup hook from automatically depending on the `out` output by default, which was necessary to prevent an infinite cycle since my `out` output depends on all the other outputs.
- Setting [`outputSpecified = true;`](https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/pkgs/development/cuda-modules/generic-builders/manifest.nix#L322-L327) and [`meta.outputsToInstall = [ "out" ];`](https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/pkgs/development/cuda-modules/generic-builders/manifest.nix#L346-L348) allowed me to prevent `stdenv.mkDerivation` from using the `dev` output by default and instead use the `out` output of each redistributable CUDA package, which contained the totality of the redistributable tarball.

The second change had the unfortunate side-effect that the [`getOutput`](https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/lib/attrsets.nix#L1764-L1799)-based family of functions (e.g., `getLib`, `getDev`, etc.) no longer had any effect as they relied on the value of `outputSpecified` to decide whether to attempt getting a different output.
In a way, I viewed this as a feature, as I had long desired errors in the case an output was missing -- the `getOutput`-based family of functions all used fallbacks, whereas direct access via `.lib` and the like would throw an evaluation error if the output were unavailable.

As a result of these changes, the `out` output still presented as the entirety of the redistributable tarball and individual components became available as separate outputs in such a way that downstream could effectively "opt-in" to them.

This change was eventually merged, breaking very few packages (that we know of) and allowing packages to further reduce their closure size by leveraging splayed outputs.

[^1]:
    The distinction between the monolithic CUDA Toolkit runfile installer and CUDA redistributables is important but out of the scope of this response.
    I think I've written about it elsewhere, but I can't remember.

[^2]: They had additionally asked for ways to prevent the PyTorch closure exploding in size again (e.g., closure size checks), but I couldn't think of a way to ensure that in general given the closure size is also a function of the amount of code PyTorch generates, which in turn depends on what the user requires in terms of `config.cudaCapabilities`.

### On 24.11 and the prelude to the rewrite

TODO: changes to default propagated outputs (e.g., removal of `static`), setup hooks, and others.

After the 24.05 release, [changes made to the redistributable package builder](https://github.com/NixOS/nixpkgs/pull/323056) restored the functionality of the `getOutput`-based family of functions and reverted the introduction of multiple outputs setup hook-controlling variables (see [On 24.05 and dependency handling in Nix and Nixpkgs](#on-2405-and-dependency-handling-in-nix-and-nixpkgs)).
As a result, the `out` output, which was previously the union of all other outputs, became essentially empty.
Additionally, the `dev` input now depended on most of the other outputs as a result of the multiple outputs setup hook.
Given `stdenv.mkDerivations`'s preference for the `dev` output, the net result was that packages which did not use explicit outputs were provided the `dev` output, which in turn brought the other outputs into the closure.
Nix was then free to remove from the runtime closure any output which was unreferenced, something the `symlinkJoin` variant of the `out` output had prevented by way of maintaining references to every output, effectively granting packages already using CUDA redistributables most of the size savings they'd see by moving to explicit splayed outputs.

## 25.05 & Beyond

A rewrite was imminent because we are unhappy with how CUDA package sets were generated within Nixpkgs.
