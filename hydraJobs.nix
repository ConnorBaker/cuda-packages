{ lib, nixpkgsInstances }:

let
  inherit (lib.attrsets)
    attrNames
    attrValues
    intersectAttrs
    isAttrs
    isDerivation
    ;
  inherit (lib.cuda.utils) mkCudaPackagesVersionedName mkRealArchitecture;
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
      inherit (pkgs) cudaPackages;
      inherit (pkgs.releaseTools) aggregate;
      setup-hooks = [
        pkgs.arrayUtilitiesHook
        pkgs.deduplicateRunpathEntriesHook
      ];
      core = [
        cudaPackages.onnx
        cudaPackages.onnx-tensorrt
        cudaPackages.onnxruntime
        cudaPackages.opencv4
        cudaPackages.pycuda
        cudaPackages.warp
      ];
      extras = [ ];
    in
    {
      setup-hooks = aggregate {
        name = "${namePrefix}-pkgs-setup-hooks";
        meta = {
          description = "Setup hooks which are non-members of the CUDA package set responsible for basic CUDA package set functionality";
          maintainers = lib.teams.cuda.members;
        };
        constituents = map hydraJob setup-hooks;
      };
      setup-hooks-tests = aggregate {
        name = "${namePrefix}-pkgs-setup-hooks-tests";
        meta = {
          description = "Test suites for setup hooks which are non-members of the CUDA package set responsible for basic CUDA package set functionality";
          maintainers = lib.teams.cuda.members;
        };
        constituents = concatMap (pkg: map hydraJob (getPassthruTests pkg)) setup-hooks;
      };
      core = aggregate {
        name = "${namePrefix}-pkgs-core";
        meta = {
          description = "Non-members of the CUDA package set which are required to build";
          maintainers = lib.teams.cuda.members;
        };
        # TODO: These need to be moved out of the package set
        constituents = map hydraJob core;
      };
      extras = aggregate {
        name = "${namePrefix}-pkgs-extras";
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
      inherit (pkgs) system;
      inherit (pkgs.releaseTools) aggregate;

      cudaPackages = pkgs.pkgsCuda.${realArch}.cudaPackagesVersions.${cudaPackagesVersionedName};

      inherit (cudaPackages.flags) isJetsonBuild;

      realArch = mkRealArchitecture cudaCapability;
      cudaPackagesVersionedName = mkCudaPackagesVersionedName cudaMajorMinorPatchVersion;
      namePrefix = "${system}-${realArch}-${cudaPackagesVersionedName}";

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
          cudaPackages.libmathdx
          cudaPackages.saxpy
        ]
        # Non-Jetson packages
        ++ optionals (!isJetsonBuild) [
          cudaPackages.nccl # TODO: Exclude on jetson platforms
          cudaPackages.nccl-tests
        ]
        # TODO: These might move to core-external
        ++ [
          cudaPackages.cudnn-frontend
          cudaPackages.cutlass
          cudaPackages.tensorrt-python
        ];

      extras = [ ];
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

      # Tests for pkgs using a different global version of the CUDA package set
      pkgs = mkPkgsJobs namePrefix cudaPackages.pkgs;
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
    }
    // mkPkgsJobs "x86_64-linux" pkgs;

  aarch64-linux =
    let
      pkgs = nixpkgsInstances.aarch64-linux;
    in
    {
      # Jetson Orin
      ${mkRealArchitecture "8.7"} = {
        # JetPack 5 only supports up to 12.2.2
        ${mkCudaPackagesVersionedName "12.2.2"} = mkCudaPackagesJobs pkgs "8.9" "12.2.2";
        # ${mkCudaPackagesVersionedName "12.6.3"} = mkCudaPackagesJobs pkgs "8.9" "12.6.3";
      };
      # Ada Lovelace
      # ${mkRealArchitecture "8.9"} = {
      #   ${mkCudaPackagesVersionedName "12.2.2"} = mkCudaPackagesJobs pkgs "8.9" "12.2.2";
      #   ${mkCudaPackagesVersionedName "12.6.3"} = mkCudaPackagesJobs pkgs "8.9" "12.6.3";
      # };
    }
    // mkPkgsJobs "aarch64-linux" pkgs;
}
