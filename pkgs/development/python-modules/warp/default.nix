{
  autoAddDriverRunpath,
  build,
  buildPythonPackage,
  cmake,
  config,
  cudaPackages,
  cudaSupport ? config.cudaSupport,
  fetchFromGitHub,
  lib,
  llvmPackages,
  ninja,
  numpy,
  python3,
  setuptools,
  wheel,
}:
let
  inherit (cudaPackages)
    cuda_cccl
    cuda_cudart
    cuda_nvcc
    cuda_nvrtc
    flags
    libmathdx
    libnvjitlink
    ;
  inherit (lib) maintainers teams;
  inherit (lib.attrsets) getBin getOutput;
  inherit (lib.strings) concatStringsSep;

  # TODO: Replace in-tree CUTLASS checkout with ours?
  # TODO: Allow re-use of existing LLVM/Clang binaries instead of building from source.
  # NOTE: It is working currently!
  # >>> import warp
  # >>> warp.is_cpu_available()
  # Warp 1.5.0 initialized:
  #   CUDA Toolkit 12.6, Driver 12.6
  #   Devices:
  #     "cpu"      : "CPU"
  #     "cuda:0"   : "NVIDIA GeForce RTX 4090" (24 GiB, sm_89, mempool enabled)
  #   Kernel cache:
  #     /home/connorbaker/.cache/warp/1.5.0
  # True
  finalAttrs = {
    # Must opt-out of __structuredAttrs which is set to true by default by cudaPackages.callPackage, but currently
    # incompatible with Python packaging: https://github.com/NixOS/nixpkgs/pull/347194.
    __structuredAttrs = false;

    pname = "warp";

    version = "1.5.1-unstable-2025-01-15";

    src = fetchFromGitHub {
      owner = "NVIDIA";
      repo = "warp";
      rev = "c168fc67110dd887bd495052a27fc585b2826c98";
      hash = "sha256-grAMMP8NeR5h9Of8iKzY5y+fdO1Wu2LDpbv7VzT9FAw=";
    };

    pyproject = true;

    build-system = [
      build
      setuptools
      wheel
    ];

    # NOTE: While normally we wouldn't include autoAddDriverRunpath for packages built from source, since Warp
    # will be loading GPU drivers at runtime, we need to inject the path to our video drivers.
    nativeBuildInputs = [
      autoAddDriverRunpath
      cuda_nvcc
      cmake
      llvmPackages.llvm.monorepoSrc
      ninja
    ];

    prePatch =
      # Patch build_dll.py to use our gencode flags rather than NVIDIA's very broad defaults.
      ''
        nixLog "patching build_dll.py to use our gencode flags"
        substituteInPlace warp/build_dll.py \
          --replace-fail \
            'nvcc_opts = gencode_opts + [' \
            'nvcc_opts = ["${concatStringsSep ''","'' flags.gencode}"] + ['
      ''
      # Patch build_dll.py to use dynamic libraries rather than static ones.
      # NOTE: We do not patch the `nvptxcompiler_static` path because it is not available as a dynamic library.
      + ''
        nixLog "patching build_dll.py to use dynamic libraries"
        substituteInPlace warp/build_dll.py \
          --replace-fail \
            '-lcudart_static' \
            '-lcudart' \
          --replace-fail \
            '-lnvrtc_static' \
            '-lnvrtc' \
          --replace-fail \
            '-lnvrtc-builtins_static' \
            '-lnvrtc-builtins' \
          --replace-fail \
            '-lnvJitLink_static' \
            '-lnvJitLink' \
          --replace-fail \
            '-lmathdx_static' \
            '-lmathdx'
      '';

    dontUseCmakeConfigure = true;

    dontUseNinjaBuild = true;

    # Run the build script which creates components necessary to build the wheel.
    # NOTE: Building standalone allows us to avoid trying to fetch a pre-built binary or
    # bootstraping Clang/LLVM.
    # NOTE: The `cuda_path` argument is the directory which contains `bin/nvcc`.
    preBuild = ''
      nixLog "running build_lib.py to create components necessary to build the wheel"
      "${python3.pythonOnBuildForHost.interpreter}" build_lib.py \
        --cuda_path "${getBin cuda_nvcc}" \
        --libmathdx_path "${libmathdx}" \
        --build_llvm \
        --llvm_source_path "${llvmPackages.llvm.monorepoSrc}"
    '';

    dependencies = [
      numpy
    ];

    buildInputs = [
      (getOutput "include" cuda_cccl) # <cub/cub.cuh>
      (getOutput "static" cuda_nvcc) # dependency on nvptxcompiler_static; no dynamic version available
      cuda_cudart
      cuda_nvcc
      cuda_nvrtc
      libmathdx
      libnvjitlink
    ];

    dontUseNinjaInstall = true;

    doCheck = true;

    meta = {
      description = "A Python framework for high performance GPU simulation and graphics";
      broken = !cudaSupport;
      homepage = "https://github.com/NVIDIA/warp";
      license = {
        fullName = "NVIDIA Software License Agreement";
        url = "https://www.nvidia.com/en-us/agreements/enterprise-software/nvidia-software-license-agreement/";
        free = false;
      };
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      maintainers = (with maintainers; [ connorbaker ]) ++ teams.cuda.members;
    };
  };
in
buildPythonPackage finalAttrs
