# History

[Return to index.](../README.md)

TODO(@ConnorBaker): Replace occurrences of first-person with my handle to make clear authorship/point of view is not representative of the CUDA Maintainers team or Nixpkgs as a whole.

## On 24.05 and dependency handling in Nix and Nixpkgs

The CUDA redistributable tarballs NVIDIA publishes had been available since the CUDA 11.4 release and the CUDA Maintainers (myself included) had tried to make efforts to move packages over to them instead of the monolithic runfile installer.[^1] Moving a package from the runfile installer to redistributable packages brought an immediate reduction in closure size, just by virtue of including fewer packages. However, the implementation of redistributable packaging had problems, the largest being the organization of the package outputs: static libraries often ended up getting propagated and stuck in the runtime closure of various packages!

A lot of the way CUDA packaging in 24.05 was structured was a direct result of the work I had done for PDT Partners (see [here](https://discourse.nixos.org/t/cuda-team-roadmap-and-call-for-sponsors/29495)). They were primarily concerned with closure size of PyTorch and a few other libraries and so the work that I did was focused on making dependencies explicit -- that meant moving from the monolithic CUDA Toolkit runfile installer (currently named [`cudatoolkit-legacy-runfile`](https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/pkgs/top-level/cuda-packages.nix#L75)) to specific components of each redistributable tarball NVIDIA publishes (like header files or static libraries).[^2]

CUDA redistributables are materially different compared to the majority of Nixpkgs in terms of availability (binary only), license (unfree), and size (big). As a result, a number of the decisions made in construction of `stdenv`'s setup hooks and the setting of defaults don't handle our use case well.

To slim down closure size, the approach that I (Connor) took was to split every package into distinct components and outputs (header files in the `include` output, binaries in the `bin` output, dynamic libraries in the `lib` output, static libraries in the `static` output, etc.) and make the `out` output a `symlinkJoin` of the others. This required that I change some values used by the multiple outputs setup hook:

- Setting [`propagatedBuildOutputs = false;`](https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/pkgs/development/cuda-modules/generic-builders/manifest.nix#L316-L320) allowed me to prevent the multiple outputs setup hook from automatically depending on the `out` output by default, which was necessary to prevent an infinite cycle since my `out` output depends on all the other outputs.
- Setting [`outputSpecified = true;`](https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/pkgs/development/cuda-modules/generic-builders/manifest.nix#L322-L327) and [`meta.outputsToInstall = [ "out" ];`](https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/pkgs/development/cuda-modules/generic-builders/manifest.nix#L346-L348) allowed me to prevent `stdenv.mkDerivation` from using the `dev` output by default and instead use the `out` output of each redistributable CUDA package, which contained the totality of the redistributable tarball.

The second change had the unfortunate side-effect that the [`getOutput`](https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/lib/attrsets.nix#L1764-L1799)-based family of functions (e.g., `getLib`, `getDev`, etc.) no longer had any effect as they relied on the value of `outputSpecified` to decide whether to attempt getting a different output. In a way, I viewed this as a feature, as I had long desired errors in the case an output was missing -- the `getOutput`-based family of functions all used fallbacks, whereas direct access via `.lib` and the like would throw an evaluation error if the output were unavailable.

As a result of these changes, the `out` output still presented as the entirety of the redistributable tarball and individual components became available as separate outputs in such a way that downstream could effectively "opt-in" to them.

This change was eventually merged, breaking very few packages (that we know of) and allowing packages to further reduce their closure size by leveraging splayed outputs.

[^1]:
    The distinction between the monolithic CUDA Toolkit runfile installer and CUDA redistributables is important but out of the scope of this response.
    I think I've written about it elsewhere, but I can't remember.

[^2]: They had additionally asked for ways to prevent the PyTorch closure exploding in size again (e.g., closure size checks), but I couldn't think of a way to ensure that in general given the closure size is also a function of the amount of code PyTorch generates, which in turn depends on what the user requires in terms of `config.cudaCapabilities`.

### On 24.11 and the prelude to the rewrite

TODO: changes to default propagated outputs (e.g., removal of `static`), setup hooks, and others.

After the 24.05 release, [changes made to the redistributable package builder](https://github.com/NixOS/nixpkgs/pull/323056) restored the functionality of the `getOutput`-based family of functions and reverted the introduction of multiple outputs setup hook-controlling variables (see [On 24.05 and dependency handling in Nix and Nixpkgs](#on-2405-and-dependency-handling-in-nix-and-nixpkgs)). As a result, the `out` output, which was previously the union of all other outputs, became essentially empty. Additionally, the `dev` input now depended on most of the other outputs as a result of the multiple outputs setup hook. Given `stdenv.mkDerivations`'s preference for the `dev` output, the net result was that packages which did not use explicit outputs were provided the `dev` output, which in turn brought the other outputs into the closure. Nix was then free to remove from the runtime closure any output which was unreferenced, something the `symlinkJoin` variant of the `out` output had prevented by way of maintaining references to every output, effectively granting packages already using CUDA redistributables most of the size savings they'd see by moving to explicit splayed outputs.

## 25.05 & Beyond

A rewrite was imminent because we are unhappy with how CUDA package sets were generated within Nixpkgs.
