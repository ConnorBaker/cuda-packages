# Setup Hooks

[Return to index.](../../README.md)

[Return to Digressions.](./README.md)

Setup hooks provide a way to execute arbitrary code at various points in the build process of a Nix derivation and are equally powerful and dangerous:[^1]

> For example, if a derivation path is mentioned more than once, Nix itself doesn’t care and makes sure the dependency derivation is already built just the same—depending is just needing something to exist, and needing is idempotent. However, a dependency specified twice will have its setup hook run twice, and that could easily change the build environment (though a well-written setup hook will therefore strive to be idempotent so this is in fact not observable). More broadly, setup hooks are anti-modular in that multiple dependencies, whether the same or different, should not interfere and yet their setup hooks may well do so.

## Most setup hooks aren't idempotent

TODO(@connorbaker): Give examples of double-registration, etc.

## Setup hooks can enforce correctness properties

TODO(@connorbaker): Finish this section.

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

[^1]: Package setup hooks: <https://nixos.org/manual/nixpkgs/stable/#ssec-setup-hooks>
