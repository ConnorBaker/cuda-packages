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

## Improve packaging experience cont.

- CUDA packages can fail in _many_ ways--some of which can be caught before runtime.
  - For example, check for NVCC host compiler leakage.
  - Stub libraries in runpath (won't look for actual library in `/run/opengl-driver/lib`). (clobbering)
  - Goal: Push runtime failures to build time.
    - How? Setup hooks!
