{
  cudaLib,
  lib,
  nixpkgsInstances,
}:
let
  inherit (cudaLib.utils) flattenDrvTree mkCudaPackagesVersionedName mkRealArchitecture;
  inherit (lib.attrsets)
    attrNames
    attrValues
    intersectAttrs
    isAttrs
    isDerivation
    optionalAttrs
    ;
  inherit (lib.customisation) hydraJob;
  inherit (lib.lists)
    concatMap
    filter
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

  # Creates jobs using the `pkgs` package set.
  # These are jobs which build and test non-members of the CUDA package set which are needed by or use CUDA package
  # sets.
  # Of note, these are only run against the default version of the CUDA package set.
  mkPkgsJobs =
    namePrefix: pkgs:
    let
      inherit (pkgs.releaseTools) aggregate;
      setup-hooks = [
        pkgs.arrayUtilitiesHook
        pkgs.deduplicateRunpathEntriesHook
      ];
      core = [
        pkgs.opencv4
      ];
      extras = [
        pkgs.clog
        pkgs.cpuinfo
      ];
    in
    {
      core = aggregate {
        name = "${namePrefix}-core";
        meta = {
          description = "Non-members of the CUDA package set which are required to build";
          maintainers = lib.teams.cuda.members;
        };
        constituents = map hydraJob core;
      };
      extras = aggregate {
        name = "${namePrefix}-extras";
        meta = {
          description = "Non-members of the CUDA package set which are not required to build";
          maintainers = lib.teams.cuda.members;
        };
        constituents = map hydraJob extras;
      };
    }
    # Since the CUDA package sets *depend on* the setup hooks (and not the other way around), it doesn't make sense
    # to build them for arbitrary prefixes (including variants of `pkgs` with different default CUDA package sets).
    // optionalAttrs (pkgs.system == namePrefix) {
      setup-hooks = aggregate {
        name = "${namePrefix}-setup-hooks";
        meta = {
          description = "Setup hooks which are non-members of the CUDA package set responsible for basic CUDA package set functionality";
          maintainers = lib.teams.cuda.members;
        };
        constituents = map hydraJob setup-hooks;
      };
      setup-hooks-tests = aggregate {
        name = "${namePrefix}-setup-hooks-tests";
        meta = {
          description = "Test suites for setup hooks which are non-members of the CUDA package set responsible for basic CUDA package set functionality";
          maintainers = lib.teams.cuda.members;
        };
        constituents = concatMap (pkg: map hydraJob (getPassthruTests pkg)) setup-hooks;
      };
    };

  mkPython3PackagesJobs =
    namePrefix: python3Packages:
    let
      inherit (python3Packages.pkgs.releaseTools) aggregate;
      core = [
        python3Packages.onnx
        python3Packages.onnx-tensorrt
        python3Packages.onnxruntime
        python3Packages.tensorrt-python
      ];
      extras = [
        python3Packages.warp
      ];
    in
    {
      core = aggregate {
        name = "${namePrefix}-core";
        meta = {
          description = "Non-members of the CUDA package set which are required to build";
          maintainers = lib.teams.cuda.members;
        };
        constituents = map hydraJob core;
      };
      extras = aggregate {
        name = "${namePrefix}-extras";
        meta = {
          description = "Non-members of the CUDA package set which are not required to build";
          maintainers = lib.teams.cuda.members;
        };
        constituents = map hydraJob extras;
      };
    };

  mkCudaPackagesJobs =
    pkgs: cudaCapability: cudaMajorMinorPatchVersion:
    let
      inherit (pkgs.releaseTools) aggregate;

      cudaPackages = pkgs.pkgsCuda.${realArch}.cudaPackagesVersions.${cudaPackagesVersionedName};

      inherit (cudaPackages.flags) isJetsonBuild;

      realArch = mkRealArchitecture cudaCapability;
      cudaPackagesVersionedName = mkCudaPackagesVersionedName cudaMajorMinorPatchVersion;
      namePrefix = "${pkgs.system}-${realArch}-${cudaPackagesVersionedName}";

      # TODO: Document requirement that hooks both have an attribute path ending with `Hook` and a `name` attribute
      # ending with `-hook`, and that setup hooks are all top-level.
      setup-hooks = concatMap (
        attrName:
        let
          attrValue = cudaPackages.${attrName};
        in
        optionals (hasSuffix "Hook" attrName && hasSuffix "-hook" attrValue.name) [ attrValue ]
      ) (attrNames cudaPackages);

      redists = pipe cudaPackages [
        # Keep only the attribute names in cudaPackages which come from packageConfigs
        (intersectAttrs cudaPackages.cudaPackagesConfig.packageConfigs)
        attrValues
        # Filter out packages unavailable for the platform
        (filter (pkg: pkg.meta.available))
      ];

      core =
        [
          cudaPackages.cudatoolkit
          cudaPackages.cudnn-frontend
          cudaPackages.cutlass
          cudaPackages.libmathdx
          cudaPackages.saxpy
        ]
        # Non-Jetson packages
        ++ optionals (!isJetsonBuild) [
          cudaPackages.nccl # TODO: Exclude on jetson systems
          cudaPackages.nccl-tests
        ];

      extras = [ ];

      all = attrValues (flattenDrvTree cudaPackages);
    in
    {
      setup-hooks = aggregate {
        name = "${namePrefix}-setup-hooks";
        meta = {
          description = "Setup hooks responsible for basic cudaPackages functionality";
          maintainers = lib.teams.cuda.members;
        };
        constituents = map hydraJob setup-hooks;
      };
      setup-hooks-tests = aggregate {
        name = "${namePrefix}-setup-hooks-tests";
        meta = {
          description = "Test suites for setup-hooks";
          maintainers = lib.teams.cuda.members;
        };
        constituents = concatMap (pkg: map hydraJob (getPassthruTests pkg)) setup-hooks;
      };
      redists = aggregate {
        name = "${namePrefix}-redists";
        meta = {
          description = "CUDA packages redistributables which are required to build";
          maintainers = lib.teams.cuda.members;
        };
        constituents = map hydraJob redists;
      };
      core = aggregate {
        name = "${namePrefix}-core";
        meta = {
          description = "Members of the CUDA package set, excluding redistributables, which are required to build";
          maintainers = lib.teams.cuda.members;
        };
        constituents = map hydraJob core;
      };
      extras = aggregate {
        name = "${namePrefix}-extras";
        meta = {
          description = "Members of the CUDA package set which are not required to build";
          maintainers = lib.teams.cuda.members;
        };
        constituents = map hydraJob extras;
      };
      # NOTE: The `all` job is helpful for keeping an eye on total package set closure size. Additionally, having a
      # single closure for the entire package set lets us more easily debug and troubleshoot mishaps where members of
      # the package set bring in (perhaps transitively) packages which depend on different versions of the package set!
      # e.g.,
      # nix why-depends --derivation .#hydraJobs.x86_64-linux.sm_89.cudaPackages_12_2_2.all /nix/store/17nqxa9fdv3kfyrl7yd8vkfqd0zd67rl-cuda12.6-cuda_cccl-12.6.77.drv
      all = aggregate {
        name = "${namePrefix}-all";
        meta = {
          description = "All members of the CUDA package set, including their tests";
          maintainers = lib.teams.cuda.members;
        };
        constituents = map hydraJob all ++ concatMap (pkg: map hydraJob (getPassthruTests pkg)) all;
      };

      # Tests for pkgs using a different global version of the CUDA package set
      pkgs = mkPkgsJobs "${namePrefix}-pkgs" cudaPackages.pkgs;
      python3Packages = mkPython3PackagesJobs "${namePrefix}-pkgs-python3Packages" cudaPackages.pkgs.python3Packages;
    };
in
{
  x86_64-linux =
    let
      pkgs = nixpkgsInstances.x86_64-linux;
    in
    {
      # Ada Lovelace
      ${mkRealArchitecture "8.9"} = {
        ${mkCudaPackagesVersionedName "12.2.2"} = mkCudaPackagesJobs pkgs "8.9" "12.2.2";
        ${mkCudaPackagesVersionedName "12.6.3"} = mkCudaPackagesJobs pkgs "8.9" "12.6.3";
      };
      python3Packages = mkPython3PackagesJobs "x86_64-linux-pkgs-python3Packages" pkgs.python3Packages;
    }
    // mkPkgsJobs "x86_64-linux-pkgs" pkgs;

  aarch64-linux =
    let
      pkgs = nixpkgsInstances.aarch64-linux;
    in
    {
      # Jetson Orin
      ${mkRealArchitecture "8.7"} = {
        # JetPack 5 only supports up to 12.2.2
        ${mkCudaPackagesVersionedName "12.2.2"} = mkCudaPackagesJobs pkgs "8.7" "12.2.2";
        # ${mkCudaPackagesVersionedName "12.6.3"} = mkCudaPackagesJobs pkgs "8.7" "12.6.3";
      };
      # Ada Lovelace
      # ${mkRealArchitecture "8.9"} = {
      #   ${mkCudaPackagesVersionedName "12.2.2"} = mkCudaPackagesJobs pkgs "8.9" "12.2.2";
      #   ${mkCudaPackagesVersionedName "12.6.3"} = mkCudaPackagesJobs pkgs "8.9" "12.6.3";
      # };
      python3Packages = mkPython3PackagesJobs "aarch64-linux-pkgs-python3Packages" pkgs.python3Packages;
    }
    // mkPkgsJobs "aarch64-linux-pkgs" pkgs;
}
