# upstreamable-lib

A collection of library functions which are more generic than required by CUDA packages and may be candidates for upstreaming to Nixpkgs' `lib`.

As such, they are not allowed to accept `cuda-lib` as an argument.

## attrsets

### flattenAttrs

On potential performance improvements:

Push evaluation of the attribute set into different nix derivations, so they can run in parallel, then aggregate the result and use IFD? Could be similar to what David Hau did:
<https://github.com/DavHau/nix-eval-cache>.

The distribution of packages is not uniform among package sets and (about?) a fourth to a third of packages are at the top-level. Iterating over the top-level is a sequential process, so if we cannot parallelize that, we need to find performance gains elsewhere (like evaluating each of the top-level recursable attributes in parallel).

Beyond that, some top-level packages come _from_ package sets. Not sure what this means about sharing... but, in the current CPP Nix implementation, since attribute sets are strict in their keys, it causes allocation (likely just of the symbols of the attrset and thunks for the values, but still). To avoid that, you'd need to know, ahead of time, which top-level packages are actually aliases to packages inside package sets.

Here's a standard run of `flattenAttrs` on the top-level of `pkgs`:

```console
Command being timed: "nix eval --json --read-only --no-eval-cache --show-trace -L -v .#adaPkgsDrvs"
User time (seconds): 73.73
System time (seconds): 5.54
Percent of CPU this job got: 91%
Elapsed (wall clock) time (h:mm:ss or m:ss): 1:27.07
Average shared text size (kbytes): 0
Average unshared data size (kbytes): 0
Average stack size (kbytes): 0
Average total size (kbytes): 0
Maximum resident set size (kbytes): 18129480
Average resident set size (kbytes): 0
Major (requiring I/O) page faults: 13
Minor (reclaiming a frame) page faults: 4679386
Voluntary context switches: 39760
Involuntary context switches: 194
Swaps: 0
File system inputs: 13827588
File system outputs: 0
Socket messages sent: 0
Socket messages received: 0
Signals delivered: 0
Page size (bytes): 4096
Exit status: 0
```

```json
{
  "cpuTime": 73.69461059570313,
  "envs": {
    "bytes": 3809262736,
    "elements": 283831060,
    "number": 192326782
  },
  "gc": {
    "heapSize": 16855113728,
    "totalBytes": 32269115408
  },
  "list": {
    "bytes": 3479238408,
    "concats": 18211283,
    "elements": 434904801
  },
  "nrAvoided": 229099286,
  "nrExprs": 3797460,
  "nrFunctionCalls": 174195878,
  "nrLookups": 87979170,
  "nrOpUpdateValuesCopied": 494915787,
  "nrOpUpdates": 23179182,
  "nrPrimOpCalls": 93486312,
  "nrThunks": 263345729,
  "sets": {
    "bytes": 11068244544,
    "elements": 652926935,
    "number": 38838349
  },
  "sizes": {
    "Attr": 16,
    "Bindings": 16,
    "Env": 8,
    "Value": 24
  },
  "symbols": {
    "bytes": 4661692,
    "number": 238869
  },
  "values": {
    "bytes": 8062978704,
    "number": 335957446
  }
}
```

Here's the same run, but where `flattened = mergeAttrsList (included ++ recursed);` was replaced with `flattened = mergeAttrsList included;`, to get an idea of how much time we spend just on the top-level. It's larger than I had hoped for, indicating that _most_ of the time is spent on the top-level.

```console
Command being timed: "nix eval --json --read-only --no-eval-cache --show-trace -L -v .#adaPkgsDrvs"
User time (seconds): 55.66
System time (seconds): 3.16
Percent of CPU this job got: 99%
Elapsed (wall clock) time (h:mm:ss or m:ss): 0:58.94
Average shared text size (kbytes): 0
Average unshared data size (kbytes): 0
Average stack size (kbytes): 0
Average total size (kbytes): 0
Maximum resident set size (kbytes): 12678896
Average resident set size (kbytes): 0
Major (requiring I/O) page faults: 0
Minor (reclaiming a frame) page faults: 3274614
Voluntary context switches: 2273
Involuntary context switches: 185
Swaps: 0
File system inputs: 7032024
File system outputs: 0
Socket messages sent: 0
Socket messages received: 0
Signals delivered: 0
Page size (bytes): 4096
Exit status: 0
```

```json
{
  "cpuTime": 55.63727951049805,
  "envs": {
    "bytes": 2830919240,
    "elements": 210364903,
    "number": 143500002
  },
  "gc": {
    "heapSize": 11714887680,
    "totalBytes": 24228814144
  },
  "list": {
    "bytes": 2337248872,
    "concats": 14244633,
    "elements": 292156109
  },
  "nrAvoided": 170076591,
  "nrExprs": 3479131,
  "nrFunctionCalls": 130025032,
  "nrLookups": 66182901,
  "nrOpUpdateValuesCopied": 379942542,
  "nrOpUpdates": 16744513,
  "nrPrimOpCalls": 69661890,
  "nrThunks": 197629300,
  "sets": {
    "bytes": 8493085248,
    "elements": 502004965,
    "number": 28812863
  },
  "sizes": {
    "Attr": 16,
    "Bindings": 16,
    "Env": 8,
    "Value": 24
  },
  "symbols": {
    "bytes": 2858790,
    "number": 178091
  },
  "values": {
    "bytes": 6193654872,
    "number": 258068953
  }
}
```
