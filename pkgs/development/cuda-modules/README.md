# `cuda-modules`

This is the index of developer-facing documentation for Nixpkgs' CUDA packaging.

- [History](./doc/history.md)
- [Design Goals](./doc/design-goals.md)
- [Architecture](./doc/architecture.md)
- [Implementation](./doc/implementation.md)
- [FAQ](./doc/faq.md)
- [Glossary](./doc/glossary.md)

## Digression: Setup Hooks

- Executable arbitrary Bash throughout the run of `stdenv.mkDerivation`.
  - Because `mkDerivation` is implemented by `setup.sh`, setup hooks let you do arbitrary stuff inside `mkDerivation`.
- Typically, build systems, like `cmake`, which are packaged in Nixpkgs, will provide setup hooks which are automatically pulled in when the tool is included in `nativeBuildInputs`.
  - These setup hooks function as shims invoking the build system during the relevant phase.
- Setup hooks can also be used to override or extend phases.
  - For example, Python packages include a hook which introduces a phase which ensures Python is able to import a list of packages (a custom post-install phase).
- Setup hooks can be used to enforce correctness properties.
  - e.g.: `noBrokenSymlinks` hook
  - There are different granularities to correctness.
    - Derivation granularity
      - One correctness that exists only at this level is that _an_ output must exist (e.g. `bin`, `lib`, `dev`, `doc`, etc).
      - We could have additional granularities.
        - One new addition could be Phase granularity.
          - For example, you could run `noBrokenSymlinks` and enforce that each phase finishes with no broken symlinks.
- Currently, only enforced at a single point in the derivation; cannot catch exceptions produced after the check has run.
- To allow setup hooks which check correctness to run multiple times per derivation, they must be idempotent.
- Idempotence: A property where of certain operations whereby they can be applied multiple times without changing the result beyond the initial application.
- Setup hooks which check correctness properties must be idempotent.
  - Guard against multiple inclusion.
  - Prevent undue modification of state (e.g. registering hook multiple times).
- Unclear currently what are the best practices for ensuring correctness per-phase.

## Improve packaging experience cont.

- CUDA packages can fail in _many_ ways--some of which can be caught before runtime.
  - For example, check for NVCC host compiler leakage.
  - Stub libraries in runpath (won't look for actual library in `/run/opengl-driver/lib`). (clobbering)
  - Goal: Push runtime failures to build time.
    - How? Setup hooks!
