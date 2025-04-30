{
  cudaLib,
  lib,
  legacyPackages,
}:
let
  inherit (cudaLib.utils) flattenDrvTree mkRealArchitecture;
  inherit (lib.attrsets)
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
  inherit (lib.trivial) pipe;

  # The evaluation warnings which preced eval errors
  mkPkgsForHydra =
    pkgs:
    pkgs.extend (
      _: prev: {
        config = prev.config // {
          inHydra = true;
        };
      }
    );

  getPassthruTests =
    let
      go =
        testOrTestSuite:
        if isDerivation testOrTestSuite then
          [ testOrTestSuite ]
        else if isAttrs testOrTestSuite then
          concatMap go (attrValues testOrTestSuite)
        else
          [ ];
    in
    pkg: go (pkg.passthru.tests or { });

  # Creates jobs using the `pkgs` package set.
  # These are jobs which build and test non-members of the CUDA package set which are needed by or use CUDA package
  # sets.
  # Of note, these are only run against the default version of the CUDA package set.
  mkPkgsJobs =
    namePrefix: pkgs:
    let
      inherit (pkgs.cudaPackages.cudaStdenv) hasJetsonCudaCapability;
      inherit (pkgs.releaseTools) aggregate;
      setup-hooks = [
        pkgs.arrayUtilities
      ];
      core =
        [
          pkgs.ffmpeg
          pkgs.gpu-burn
          pkgs.hwloc
          pkgs.magma-cuda-static
          pkgs.nvidia-optical-flow-sdk
          pkgs.onnx
          pkgs.onnx-tensorrt
          pkgs.onnxruntime
          pkgs.opencv4
        ]
        # TODO(@connorbaker): Should these be able to build on Jetson?
        ++ optionals (!hasJetsonCudaCapability) [
          pkgs.openmpi
          pkgs.ucc
          pkgs.ucx
        ];
      extras = [
        # nvtop?
        # pkgs.katago and the various versions with different backends
        # pkgs.xpra
        pkgs.adaptivecpp
        pkgs.arrayfire
        pkgs.blender
        pkgs.btop
        pkgs.catboost
        pkgs.clog
        pkgs.cp2k
        pkgs.cpuinfo
        pkgs.ctranslate2
        pkgs.dcgm
        pkgs.digikam
        pkgs.dlib
        pkgs.elpa
        pkgs.faiss
        pkgs.firestarter
        pkgs.frei0r
        pkgs.gpt4all
        pkgs.gpufetch
        pkgs.hashcat
        pkgs.koboldcpp
        pkgs.librealsense
        pkgs.lightgbm
        pkgs.llama-cpp
        pkgs.local-ai
        pkgs.mistral-rs
        pkgs.mlt
        pkgs.mmseqs2
        pkgs.monado
        pkgs.moshi
        pkgs.mxnet
        pkgs.obs-studio
        pkgs.ollama
        pkgs.openimagedenoise
        pkgs.openmm
        pkgs.opensplat
        pkgs.opensubdiv
        pkgs.openvino
        pkgs.pcl
        pkgs.peakperf
        pkgs.siruis
        pkgs.slurm
        pkgs.spfft
        pkgs.spla
        pkgs.suitesparse # TODO: include other versions of suitesparse?
        pkgs.sunshine
        pkgs.tabby
        pkgs.terra
        pkgs.tiny-cuda-nn
        pkgs.truecrack
        pkgs.umpire
        pkgs.waifu2x-converter-cpp
        pkgs.whisper-cpp
        pkgs.wivrn
        pkgs.xgboost
        pkgs.zfp
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
      # core-tests = aggregate {
      #   name = "${namePrefix}-core-tests";
      #   meta = {
      #     description = "Test suites for non-members of the CUDA package set which are required to build";
      #     maintainers = lib.teams.cuda.members;
      #   };
      #   constituents = concatMap (pkg: map hydraJob (getPassthruTests pkg)) core;
      # };
      extras = aggregate {
        name = "${namePrefix}-extras";
        meta = {
          description = "Non-members of the CUDA package set which are not required to build";
          maintainers = lib.teams.cuda.members;
        };
        # TODO(@connorbaker): Temporarily disabled.
        # constituents = map hydraJob extras;
        constituents = [ ];
      };
      # extras-tests = aggregate {
      #   name = "${namePrefix}-extras-tests";
      #   meta = {
      #     description = "Test suites for non-members of the CUDA package set which are not required to build";
      #     maintainers = lib.teams.cuda.members;
      #   };
      #   # TODO(@connorbaker): Temporarily disabled.
      #   # constituents = concatMap (pkg: map hydraJob (getPassthruTests pkg)) extras;
      #   constituents = [ ];
      # };
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
      core = filter (drv: drv.meta.available && !drv.meta.broken) [
        python3Packages.bitsandbytes
        python3Packages.causal-conv1d
        python3Packages.codetr
        python3Packages.cuda-bindings
        python3Packages.cuda-python
        python3Packages.cupy
        python3Packages.cutlass
        python3Packages.faiss
        python3Packages.flash-attn
        python3Packages.mamba-ssm
        python3Packages.modelopt
        python3Packages.modelopt-core
        python3Packages.numba
        python3Packages.nvcomp
        python3Packages.nvidia-ml-py
        python3Packages.onnx
        python3Packages.onnx-tensorrt
        python3Packages.onnxruntime
        python3Packages.pyclibrary
        python3Packages.pycuda
        python3Packages.pynvml
        python3Packages.pytorch-metric-learning
        python3Packages.pytorch3d
        python3Packages.schedulefree
        python3Packages.tensorrt
        python3Packages.torch
        python3Packages.torch-tensorrt
        python3Packages.torchaudio
        python3Packages.torchvision
        python3Packages.transformer-engine
        python3Packages.triton
        python3Packages.warp
        python3Packages.xformers
      ];
      extras = [
        python3Packages.accelerate
        python3Packages.array-api-compat
        python3Packages.bitsandbytes
        python3Packages.face-recognition
        python3Packages.gpuctypes
        python3Packages.jax
        python3Packages.jax-cuda12-pjrt
        python3Packages.jax-cuda12-plugin
        python3Packages.jaxlib
        python3Packages.lightgbm
        python3Packages.llama-cpp-python
        python3Packages.mmcv
        python3Packages.paddlecor
        python3Packages.paddlepaddle
        python3Packages.pymatting
        python3Packages.reikna
        python3Packages.sasmodels
        python3Packages.tensorflow
        python3Packages.tinygrad
        python3Packages.vllm
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
      # core-tests = aggregate {
      #   name = "${namePrefix}-core-tests";
      #   meta = {
      #     description = "Test suites for non-members of the CUDA package set which are required to build";
      #     maintainers = lib.teams.cuda.members;
      #   };
      #   constituents = concatMap (pkg: map hydraJob (getPassthruTests pkg)) core;
      # };
      extras = aggregate {
        name = "${namePrefix}-extras";
        meta = {
          description = "Non-members of the CUDA package set which are not required to build";
          maintainers = lib.teams.cuda.members;
        };
        # TODO(@connorbaker): Temporarily disabled.
        # constituents = map hydraJob extras;
        constituents = [ ];
      };
      # extras-tests = aggregate {
      #   name = "${namePrefix}-extras-tests";
      #   meta = {
      #     description = "Test suites for non-members of the CUDA package set which are not required to build";
      #     maintainers = lib.teams.cuda.members;
      #   };
      #   # TODO(@connorbaker): Temporarily disabled.
      #   # constituents = concatMap (pkg: map hydraJob (getPassthruTests pkg)) extras;
      #   constituents = [ ];
      # };
    };

  mkCudaPackagesJobs =
    pkgs: cudaCapability: cudaPackageSetName:
    let
      inherit (cudaPackages.cudaStdenv) hasJetsonCudaCapability;
      inherit (pkgs.releaseTools) aggregate;

      cudaPackages = pkgs.pkgsCuda.${realArch}.${cudaPackageSetName};
      realArch = mkRealArchitecture cudaCapability;
      namePrefix = "${pkgs.system}-${realArch}-${cudaPackageSetName}";

      # TODO: Document requirement that hooks both have an attribute path ending with `Hook` and a `name` attribute
      # ending with `-hook`, and that setup hooks are all top-level.
      setup-hooks = [
        cudaPackages.cudaHook
        cudaPackages.markForCudaToolkitRootHook
        cudaPackages.nvccHook
      ];

      redists =
        pipe cudaPackages [
          # Keep only the attribute names in cudaPackages which come from fixups (are redistributables).
          (intersectAttrs cudaPackages.fixups)
          attrValues
          # Filter out packages unavailable for the platform
          (filter (pkg: pkg.meta.available))
        ]
        # Special case for cudnn_8_9, which is constructed manually
        ++ optionals cudaPackages.cudnn_8_9.meta.available [ cudaPackages.cudnn_8_9 ];

      core =
        [
          cudaPackages.cuda-samples
          cudaPackages.cudatoolkit
          cudaPackages.cudnn-frontend
          cudaPackages.cutlass
          cudaPackages.libmathdx
          cudaPackages.tests.saxpy # TODO: This doesn't actually run saxpy
        ]
        # Non-Jetson packages
        ++ optionals (!hasJetsonCudaCapability) [
          cudaPackages.nccl
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
      redists-tests = aggregate {
        name = "${namePrefix}-redists-tests";
        meta = {
          description = "Test suites for CUDA packages redistributables which are required to build";
          maintainers = lib.teams.cuda.members;
        };
        constituents = concatMap (pkg: map hydraJob (getPassthruTests pkg)) redists;
      };
      core = aggregate {
        name = "${namePrefix}-core";
        meta = {
          description = "Members of the CUDA package set, excluding redistributables, which are required to build";
          maintainers = lib.teams.cuda.members;
        };
        constituents = map hydraJob core;
      };
      core-tests = aggregate {
        name = "${namePrefix}-core-tests";
        meta = {
          description = "Test suites for members of the CUDA package set, excluding redistributables, which are required to build";
          maintainers = lib.teams.cuda.members;
        };
        constituents = concatMap (pkg: map hydraJob (getPassthruTests pkg)) core;
      };
      extras = aggregate {
        name = "${namePrefix}-extras";
        meta = {
          description = "Members of the CUDA package set which are not required to build";
          maintainers = lib.teams.cuda.members;
        };
        constituents = map hydraJob extras;
      };
      extras-tests = aggregate {
        name = "${namePrefix}-extras-tests";
        meta = {
          description = "Test suites for members of the CUDA package set which are not required to build";
          maintainers = lib.teams.cuda.members;
        };
        constituents = concatMap (pkg: map hydraJob (getPassthruTests pkg)) extras;
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
      pkgs = mkPkgsForHydra legacyPackages.x86_64-linux;
    in
    {
      # Ada Lovelace
      ${mkRealArchitecture "8.9"} = {
        cudaPackages_12_2 = mkCudaPackagesJobs pkgs "8.9" "cudaPackages_12_2";
        cudaPackages_12_6 = mkCudaPackagesJobs pkgs "8.9" "cudaPackages_12_6";
        cudaPackages_12_8 = mkCudaPackagesJobs pkgs "8.9" "cudaPackages_12_8";
      };
      python3Packages = mkPython3PackagesJobs "x86_64-linux-pkgs-python3Packages" pkgs.python3Packages;
    }
    // mkPkgsJobs "x86_64-linux-pkgs" pkgs;

  aarch64-linux =
    let
      pkgs = mkPkgsForHydra legacyPackages.aarch64-linux;
    in
    {
      # Jetson Orin
      ${mkRealArchitecture "8.7"} = {
        # JetPack 5 only supports up to 12.2.2
        cudaPackages_12_2 = mkCudaPackagesJobs pkgs "8.7" "cudaPackages_12_2";
      };
      python3Packages = mkPython3PackagesJobs "aarch64-linux-pkgs-python3Packages" pkgs.python3Packages;
    }
    // mkPkgsJobs "aarch64-linux-pkgs" pkgs;
}
