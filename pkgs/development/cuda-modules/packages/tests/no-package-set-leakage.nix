{
  cudaLib,
  cudaNamePrefix,
  cudaPackages,
  lib,
  runCommand,
}:
let
  inherit (builtins) unsafeDiscardStringContext;
  inherit (cudaLib.utils) collectDepsRecursive flattenDrvTree;
  inherit (lib.attrsets)
    attrValues
    getOutput
    ;
  inherit (lib.lists)
    concatMap
    filter
    head
    length
    map
    naturalSort
    unique
    ;
  inherit (lib.strings) match;
  inherit (lib.trivial) flip pipe;

  # Make sure to get all the outputs, not just the default one, to avoid leaks slipping through.
  getOutputs = drv: map (flip getOutput drv) drv.outputs or [ "out" ];
  getDrvsFromDrvTree = drvTree: attrValues (flattenDrvTree drvTree);
  cudaPackagesDrvs =
    let
      cudaPackages' = removeAttrs cudaPackages [ "backendStdenv" ] // {
        tests = removeAttrs cudaPackages.tests [ "no-package-set-leakage" ];
      };
      drvs = getDrvsFromDrvTree cudaPackages';
      testDrvs = concatMap (drv: getDrvsFromDrvTree (drv.passthru.tests or { })) drvs;
    in
    concatMap getOutputs (drvs ++ testDrvs);

  allDeps = pipe cudaPackagesDrvs [
    collectDepsRecursive
    (map (dep: unsafeDiscardStringContext "${dep}"))
  ];

  depsWithMismatchedCudaNamePrefix =
    let
      hasMismatchedCudaNamePrefix =
        path:
        let
          matches = match "^.+-(cuda[[:digit:]]+\.[[:digit:]]+)-.+$" path;
          matchedPrefix = head matches;
        in
        matches != null && length matches == 1 && matchedPrefix != cudaNamePrefix;
    in
    pipe allDeps [
      (filter hasMismatchedCudaNamePrefix)
      naturalSort
      unique
    ];
in
runCommand "tests-no-package-set-leakage"
  {
    __structuredAttrs = true;
    strictDeps = true;
    inherit depsWithMismatchedCudaNamePrefix;
  }
  ''
    if ! ((''${#depsWithMismatchedCudaNamePrefix[@]})); then
      nixLog "no package set leakage detected"
      touch "$out"
    else
      nixErrorLog "something in the closure of the ${cudaNamePrefix} package set has at least one dependency (perhaps \
    transitively) on at least one different version of the CUDA package set!"
      for dep in "''${depsWithMismatchedCudaNamePrefix[@]}"; do
        nixErrorLog "dependency $dep does not belong to the ${cudaNamePrefix} package set"
      done
      exit 1
    fi
  ''
