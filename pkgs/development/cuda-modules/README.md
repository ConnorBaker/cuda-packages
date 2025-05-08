# `cuda-modules`

This is the index of developer-facing documentation for Nixpkgs' CUDA packaging.

- [Updating](./doc/updating.md)
- [History](./doc/history.md)
- [Design Goals](./doc/design-goals.md)
- [Architecture](./doc/architecture.md)
- [Implementation](./doc/implementation.md)
- [FAQ](./doc/faq.md)
- [Digressions](./doc/digressions/README.md)
- [Glossary](./doc/glossary.md)

- `fixups`: Each file or directory (excluding `default.nix`) should contain a `callPackage`-able expression to be provided to the `overrideAttrs` attribute of a package produced by the generic manifest builder.

  These fixups are applied by `pname`, so packages with multiple versions (e.g., `cudnn`, `cudnn_8_9`, etc.) all share a single fixup function (i.e., `fixups/cudnn.nix`).
