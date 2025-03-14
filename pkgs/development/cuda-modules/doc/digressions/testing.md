# Testing

[Return to index.](../../README.md)

[Return to Digressions.](./README.md)

## Impacts of limited bandwidth

CUDA-enabled packages tend to have some of the most convoluted, eldritch, and difficult to maintain build systems across all of Nixpkgs. Furthermore:

- the number of developers able to contribute to or maintain such packaging, either upstream or within Nixpkgs, is relatively small
- CUDA support is disabled by default, so CUDA-enabled packages do not benefit from Nixpkgs' CI tooling
- breakage of CUDA-enabled packages does not prevent a PR from being merged
- contributors don't know how to check, don't have the hardware to check, or don't care to check CUDA-enabled packages functionality
- most CUDA-enabled packages are missing test suites or other niceties to verify runtime functionality

As such, any changes made to the CUDA packaging itself need to avoid widespread breakage given the limited bandwidth of the CUDA Maintainers team and availability of package maintainers, because it can take a long time to resolve them.
