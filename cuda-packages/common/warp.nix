{
  autoAddDriverRunpath,
  backendStdenv,
  cuda_cudart,
  cuda_nvcc,
  cuda_nvrtc,
  cmake,
  ninja,
  fetchFromGitHub,
  flags,
  lib,
  libmathdx,
  libnvjitlink,
  llvmPackages_19,
  python3,
}:
let
  inherit (lib.attrsets) getBin getOutput;
  inherit (lib.strings) concatStringsSep;
  inherit (python3.pkgs)
    build
    buildPythonPackage
    numpy
    setuptools
    wheel
    ;

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
    # Must opt-out of __structuredAttrs which is on by default in our stdenv, but currently incompatible with Python
    # packaging: https://github.com/NixOS/nixpkgs/pull/347194.
    __structuredAttrs = false;
    stdenv = backendStdenv;

    pname = "warp";

    version = "1.4.2-unstable-2024-11-26";

    src = fetchFromGitHub {
      owner = "NVIDIA";
      repo = "warp";
      rev = "14712b232c9224ba870f3488e6090fc0fcb820f3";
      hash = "sha256-l4iACTRj3+HY0zQ9fQwN0TVkC4wSBx/wQ41eJ8yxoyo=";
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
      llvmPackages_19.llvm.monorepoSrc
      ninja
    ];

    prePatch =
      # Patch build_dll.py to use our gencode flags rather than NVIDIA's very broad defaults.
      ''
        substituteInPlace warp/build_dll.py \
          --replace-fail \
            'nvcc_opts = gencode_opts + [' \
            'nvcc_opts = ["${concatStringsSep ''","'' flags.gencode}"] + ['
      ''
      # Patch build_dll.py to use dynamic libraries rather than static ones.
      # NOTE: We do not patch the `nvptxcompiler_static` path because it is not available as a dynamic library.
      + ''
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
      "${python3.pythonOnBuildForHost.interpreter}" build_lib.py \
        --cuda_path "${getBin cuda_nvcc}" \
        --libmathdx_path "${libmathdx}" \
        --build_llvm \
        --llvm_source_path "${llvmPackages_19.llvm.monorepoSrc}"
    '';

    dependencies = [
      numpy
    ];

    buildInputs = [
      (getOutput "static" cuda_nvcc) # dependency on nvptxcompiler_static; no dynamic version available
      cuda_cudart
      cuda_nvcc
      cuda_nvrtc
      libmathdx
      libnvjitlink
    ];

    dontUseNinjaInstall = true;

    doCheck = true;

    meta = with lib; {
      description = "A Python framework for high performance GPU simulation and graphics";
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
