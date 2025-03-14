# Dependencies and outputs in Nix and Nixpkgs

[Return to index.](../../README.md)

[Return to Digressions.](./README.md)

## Outputs are binaries first

> [!NOTE]
>
> The binaries first convention is related to default installed outputs when packages are used unqualified. The convention is unrelated to `stdenv.mkDerivation`'s preference for the `dev` output; see [`stdenv.mkDerivation` prefers the `dev` output](#stdenvmkderivation-prefers-the-dev-output) for more.

By convention, package outputs are expected to be binary first: the first output (recall that `outputs` is a list, so order matters) should be the one which contains executables provided by the package.[^1] This convention is used by `meta.outputsToInstall`.[^2]

As an example, a program providing both binaries and libraries may have the outputs `[ "bin" "out" ]`, where `bin` contains the binaries and `out` contains the libraries, or `[ "out" "lib" ]`, where `out` contains the binaries and `lib` contains the libraries. If instead the package had either binaries or libraries, outputs should be `[ "out" ]`.

## Source releases over binary releases

Nixpkgs is primarily a source-based package repository, so NixOS is primarliy a source-based distribution. Generally, when both source and binary releases are available, Nixpkgs prefers the source release, unless it cannot be built within Nixpkgs.

## Dynamic linking over static linking

Nixpkgs has a strong preference for dynamic linking, which in turn enables re-use of libraries in the store. As such, packages may reduce build times by excluding targets producing static libraries or remove them from outputs to reduce closure sizes.

## `stdenv.mkDerivation` prefers the `dev` output

> [!NOTE]
>
> The multiple outputs setup hook sets an attribute named `outputSpecified` to `true` on each of the output derivations it creates. Since `stdenv.mkDerivation` uses `lib.getDev` (a wrapper around `lib.getOutput`), the `dev` output is only selected when the derivation's `outputSpecified` attribute is absent or `false`.[^3]

NixOS/Nixpkgs (and other distributions, like Ubuntu) typically have developer variants of each package, which include header files, static libraries, and other things developers might need. Developer variants of packages in Nixpkgs are typically accessible through a package's `dev` output, while in Ubuntu they typically exist as a separate package of the same name, with a `-dev` suffix applied.

By splitting the components of a package into different packages, repositories enforce a separation of concerns and create a better user experience for a target audience of users. Developers, on the other hand, have to know to install the developer variant.

Since `stdenv.mkDerivation` is used to build packages and package installation logic is handled by `meta.outputsToInstall` (see [Outputs are binaries first](#outputs-are-binaries-first)), `stdenv.mkDerivation` selects the `dev` output for each package provided in one of the dependency arrays if the output is not explicitly provided.[^4] To prevent this preference causing breakages by way of excluding outputs providing binaries or libraries, the multiple outputs setup hook adds the `out` output as a propagated build input of the `dev` output, ensuring the `out` output is made a dependency.[^5]

## No file type group for `static`

Since the multiple outputs setup hook doesn't have the notion of a `static` output, neither does Nixpkgs.[^6] As a result, if a package produces static libraries, they are either left in the build directory (and so not available in an output) or installed in the library output by the build system.

Some package maintainers choose to move static libraries to a `dev` or `static` output, but they must do so manually. Additionally, if care is not taken to move them out of the `out` or `dev` outputs, they will be brought into the build time closure by `stdenv.mkDerivation` (see [`stdenv.mkDerivation` prefers the `dev` output](#stdenvmkderivation-prefers-the-dev-output)). Thankfully, if the static libraries are not referenced by any other derivation, they will be dropped from the runtime closure by Nix (see [Nix scans derivation outputs](#nix-scans-derivation-outputs)).

## Nix scans derivation outputs

When registering a derivation's store paths, Nix scans each for references to store paths.[^7] If no reference to a derivation brought into scope is found, it is dropped from the runtime closure.

## CUDA packages provide large static libraries

Unlike static libraries produced by most other packages in Nixpkgs, CUDA static libraries tend to be massive due to the amount of device code and number of function specializations each provide. It's not uncommon for them to approach or pass 1 GB in size, so we must be careful which output we place them in.

Unfortunately, we cannot remove them entirely, as downstream consumers of CUDA may require static libraries. One such user of static CUDA libraries is CMake's compiler detection phase, which runs as part of `cmake configure` and requires the presence of certain static CUDA libraries.

The net result is that CUDA packages must be careful to ensure static libraries are moved to a `static` output. This is, however, a manual process which much be adhered to rigorously until such a time as the multiple outputs setup hook is extended to support a `static` output (see [No file type group for `static`](#no-file-type-group-for-static)).

[^1]: Nixpkgs' "binaries first" convention: <https://nixos.org/manual/nixpkgs/stable/#multiple-output-file-binaries-first-convention>

[^2]: Implementation of `meta.outputsToInstall`: <https://github.com/NixOS/nixpkgs/blob/08c3198f1c6fd89a09f8f0ea09b425028a34de3e/pkgs/stdenv/generic/check-meta.nix#L411-L426>

[^3]: Implementation of `lig.getOutput`: <https://github.com/NixOS/nixpkgs/blob/606977bc89ccc69273afa5a22b5caca9b2b6ee1d/lib/attrsets.nix#L1796-L1799>

[^4]: `stdenv.mkDerivations`'s preference for a package's `dev` output: <https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/pkgs/stdenv/generic/make-derivation.nix#L301-L328>

[^5]: Implementation of the multiple outputs setup hook: <https://github.com/NixOS/nixpkgs/blob/0da3c44a9460a26d2025ec3ed2ec60a895eb1114/pkgs/build-support/setup-hooks/multiple-outputs.sh>

[^6]: File type groups recognized by the multiple outputs setup hook: <https://nixos.org/manual/nixpkgs/stable/#multiple-output-file-type-groups>

[^7]: Nix's store path scanning: <https://github.com/NixOS/nix/blob/e9af7a0749c1e385410e611ae2394fe79c7ea422/src/libstore/unix/build/local-derivation-goal.cc#L2440>
