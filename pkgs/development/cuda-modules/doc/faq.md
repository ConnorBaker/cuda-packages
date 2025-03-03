# FAQ

[Return to index.](../README.md)

TODO(@connorbaker): Figure out the different documents these all should live in.

## What are the design goals of Nixpkgs' CUDA packaging?

TODO(@connorbaker)

### How does JetPack NixOS fit in?

TODO(@connorbaker)

## How do I package CUDA-enabled software?

TODO(@connorbaker): This belongs in a best-practices guide.

- Include recommended patterns.

## How do I build CUDA-enabled software?

TODO(@connorbaker):

- Include Nixpkgs configuration as example
- Mention tradeoffs between number of devices targeted and compile time/binary sizes
- Mention `cuda_compat` and the role it plays on Jetson devices

## How do I run CUDA-enabled software?

TODO(@connorbaker):

- Mention `nixGL`, `nix-gl-host`, and solutions to arbitrary driver runpath on host devices
- Mention `cuda_compat` and the role it plays on Jetson devices

## Why splayed outputs?

TODO(@connorbaker):

- Reference Nix dependency tracking
- Reference default output selection
- Mention opt-in to single components for smaller build/runtime closures

## How do I minimize my closure?

TODO(@connorbaker): I don't have a good answer to that right now other than asking that people packaging CUDA-enabled packages become familiar with Nixpkgs' CUDA packaging; that's not a fair ask for a number of reasons, the largest being lack of documentation.

### Minimizing build-time closure

TODO(@connorbaker)

### Minimizing run-time closure

TODO(@connorbaker)
