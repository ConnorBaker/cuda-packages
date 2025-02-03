{ lib, nixpkgsInstances }:

let
  inherit (lib.attrsets)
    attrNames
    attrValues
    intersectAttrs
    isAttrs
    isDerivation
    recursiveUpdate
    mapAttrs'
    ;
  inherit (lib.customisation) hydraJob;
  inherit (lib.lists)
    concatMap
    filter
    foldl'
    map
    optionals
    ;
  inherit (lib.strings) hasSuffix;
  inherit (lib.trivial) pipe;

  getPassthruTests =
    let
      go =
        testOrTestSuite:
        if isDerivation testOrTestSuite then
          [ testOrTestSuite ]
        else if isAttrs testOrTestSuite then
          concatMap go (attrValues testOrTestSuite)
        else
          builtins.throw "Expected passthru.tests to contain derivations or attribute sets of derivations";
    in
    pkg: go (pkg.passthru.tests or { });

  # TODO: Document requirement that hooks both have an attribute path ending with `Hook` and a `name` attribute ending with `-hook`,
  # and that setup hooks are all top-level.
  getSetupHooks =
    cudaPackages:
    concatMap (
      attrName:
      let
        attrValue = cudaPackages.${attrName};
      in
      optionals (hasSuffix "Hook" attrName && hasSuffix "-hook" attrValue.name) [ attrValue ]
    ) (attrNames cudaPackages);

  getRedists =
    cudaPackages:
    pipe cudaPackages [
      # Keep only the attribute names in cudaPackages which come from packageConfigs
      (intersectAttrs cudaPackages.cudaPackagesConfig.packageConfigs)
      attrValues
      # Filter out packages unavailable for the platform
      (filter (pkg: pkg.meta.available))
    ];

  mkHydraJobs =
    system: realArch: cudaPackagesName:
    let
      pkgs = nixpkgsInstances.${system};
      cp = pkgs.pkgsCuda.${realArch}.${cudaPackagesName};

      inherit (pkgs.releaseTools) aggregate;

      # TODO: Until these are upstreamed, we need them to function.
      setup-hooks = getSetupHooks cp ++ [
        pkgs.arrayUtilitiesHook
        pkgs.deduplicateRunpathEntriesHook
      ];
    in
    mapAttrs'
      (name: value: {
        name = "${name}-${realArch}-${cudaPackagesName}";
        inherit value;
      })
      {
        setup-hooks.${system} = aggregate {
          name = "setup-hooks";
          meta = {
            description = "Setup hooks responsible for basic cudaPackages functionality";
            maintainers = lib.teams.cuda.members;
          };
          constituents = map hydraJob setup-hooks;
        };
        setup-hooks-tests.${system} = aggregate {
          name = "setup-hooks-tests";
          meta = {
            description = "Test suites for setup-hooks";
            maintainers = lib.teams.cuda.members;
          };
          constituents = concatMap (pkg: map hydraJob (getPassthruTests pkg)) setup-hooks;
        };
        redists.${system} = aggregate {
          name = "redists";
          meta = {
            description = "CUDA packages redistributables which are required to build";
            maintainers = lib.teams.cuda.members;
          };
          constituents = map hydraJob (getRedists cp);
        };
        core-internal.${system} = aggregate {
          name = "core-internal";
          meta = {
            description = "Members of the CUDA package set, excluding redistributables, which are required to build";
            maintainers = lib.teams.cuda.members;
          };
          constituents = map hydraJob (
            [
              cp.cudatoolkit
              cp.libmathdx
              cp.saxpy
            ]
            # Non-Jetson packages
            ++ optionals (!cp.flags.isJetsonBuild) [
              cp.nccl # TODO: Exclude on jetson platforms
              cp.nccl-tests
            ]
            # TODO: These might move to core-external
            ++ [
              cp.cudnn-frontend
              cp.cutlass
              cp.tensorrt-python
            ]
          );
        };
        # TODO: The external packages (those outside of the package set) won't be affected by changes to the CUDA version
        # because they will use the default version from the global scope.
        # We're looking at either overriding the default version globally.
        core-external.${system} = aggregate {
          name = "core-external";
          meta = {
            description = "Non-members of the CUDA package set, excluding redistributables, which are required to build";
            maintainers = lib.teams.cuda.members;
          };
          # TODO: These need to be moved out of the package set
          constituents = map hydraJob [
            cp.onnx
            cp.onnx-tensorrt
            cp.onnxruntime
            cp.opencv4
            cp.pycuda
            cp.warp
          ];
        };
        extras-internal.${system} = aggregate {
          name = "extras-internal";
          meta = {
            description = "Members of the CUDA package set which are not required to build";
            maintainers = lib.teams.cuda.members;
          };
          constituents = map hydraJob [ ];
        };
        extras-external.${system} = aggregate {
          name = "extras-external";
          meta = {
            description = "Non-members of the CUDA package set which are not required to build";
            maintainers = lib.teams.cuda.members;
          };
          constituents = map hydraJob [ ];
        };
      };
in
foldl' recursiveUpdate { } [
  # x86_64-linux
  (mkHydraJobs "x86_64-linux" "sm_89" "cudaPackages_12_2_2")
  (mkHydraJobs "x86_64-linux" "sm_89" "cudaPackages_12_6_3")

  # aarch64-linux
  # (mkHydraJobs "aarch64-linux" "sm_89" "cudaPackages_12_2_2")
  # (mkHydraJobs "aarch64-linux" "sm_89" "cudaPackages_12_6_3")

  # Jetson (limited to Jetpack 5)
  (mkHydraJobs "aarch64-linux" "sm_87" "cudaPackages_12_2_2")
]
