{
  autoPatchelfHook,
  buildPythonPackage,
  pkgsBuildHost,
  cudaPackages,
  cython,
  fastrlock,
  fetchFromGitHub,
  lib,
  mock,
  numpy,
  pytestCheckHook,
  pythonOlder,
  symlinkJoin,
}:
let
  inherit (cudaPackages)
    backendStdenv
    cuda_cudart
    cuda_nvcc
    cuda_nvrtc
    cuda_nvtx
    cuda_profiler_api
    cudaNamePrefix
    cudnn_8_9 # NOTE: Waiting on upstream to add support for CUDNN 9 or cudnn-frontend.
    flags
    libcublas
    libcufft
    libcurand
    libcusolver
    libcusparse
    libcusparse_lt
    libcutensor
    nccl
    ;

  # Allows us to use a newer release of cusparse_lt and cython
  version = "13.4.1-unstable-2025-04-20";

  getOutputsForDrv =
    drv:
    lib.concatMap
      (
        output:
        let
          drv' = lib.getOutput output drv;
        in
        lib.optionals drv'.meta.available [ drv' ]
      )
      [
        "out"
        "dev"
        "include"
        "lib"
      ];

  getOutputsForDrvs = drvs: lib.unique (lib.concatMap getOutputsForDrv drvs);

  cudatoolkit-joined = symlinkJoin {
    name = "${cudaNamePrefix}-cudatoolkit-joined";
    paths = getOutputsForDrvs [
      (lib.getOutput "include" cuda_nvcc) # Only the includes are needed
      (lib.getOutput "static" cuda_cudart) # Static libraries are explicitly required
      (lib.getOutput "stubs" cuda_cudart) # For some reason it needs the stubs
      cuda_cudart
      cuda_nvrtc
      cuda_nvtx
      cuda_profiler_api
      cudnn_8_9
      libcublas
      libcufft
      libcurand
      libcusolver
      libcusparse
      libcusparse_lt
      libcutensor
      nccl
    ];
    # NOTE: If we had more stubs, we'd need to be worried about setup hooks colliding with each other and
    # manually add them.
    # This might be a problem when building for Jetson devices.
    postBuild = ''
      nixLog "removing unnecessary $out/nix-support/propagated-build-inputs"
      rm --verbose "$out/nix-support/propagated-build-inputs"
    '';
  };
in
buildPythonPackage {
  __structuredAttrs = true;

  pname = "cupy";
  inherit version;

  disabled = pythonOlder "3.7";

  stdenv = backendStdenv;

  src = fetchFromGitHub {
    owner = "cupy";
    repo = "cupy";
    rev = "bc09632784f1376455f37fc2a075d83abeb08167";
    hash = "sha256-Zhi8SA4kE2czugoldgiMf1KjSd9uxl8mgFYKSNaG4eA=";
    fetchSubmodules = true;
  };

  build-system = [
    cython
    fastrlock
  ];

  postPatch =
    # https://github.com/cupy/cupy/blob/bc09632784f1376455f37fc2a075d83abeb08167/install/cupy_builder/_compiler.py#L170
    ''
      nixLog "patching _compiler.py to use our gencode flags"
      substituteInPlace install/cupy_builder/_compiler.py \
        --replace-fail \
          'return options' \
          'return ["${lib.concatStringsSep ''","'' flags.gencode}"]'
    ''
    # https://github.com/cupy/cupy/blob/bc09632784f1376455f37fc2a075d83abeb08167/install/cupy_builder/cupy_setup_build.py#L219
    + ''
      nixLog "removing check for compute capabilities of host"
      substituteInPlace install/cupy_builder/cupy_setup_build.py \
        --replace-fail \
          'build.check_compute_capabilities(compiler, settings)' \
          'pass'
    '';

  env = {
    CUDA_PATH = cudatoolkit-joined.outPath;
    NVCC = lib.getExe pkgsBuildHost.cudaPackages.cuda_nvcc;
  };

  # See https://docs.cupy.dev/en/v10.2.0/reference/environment.html. Setting both
  # CUPY_NUM_BUILD_JOBS and CUPY_NUM_NVCC_THREADS to NIX_BUILD_CORES results in
  # a small amount of thrashing but it turns out there are a large number of
  # very short builds and a few extremely long ones, so setting both ends up
  # working nicely in practice.
  preConfigure = ''
    export CUPY_NUM_BUILD_JOBS="$NIX_BUILD_CORES"
    export CUPY_NUM_NVCC_THREADS="$NIX_BUILD_CORES"
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    cuda_nvcc
  ];

  buildInputs = [ cudatoolkit-joined ];

  dependencies = [
    fastrlock
    numpy
  ];

  nativeCheckInputs = [
    pytestCheckHook
    mock
  ];

  # Won't work with the GPU, whose drivers won't be accessible from the build
  # sandbox
  doCheck = false;

  enableParallelBuilding = true;

  meta = {
    description = "NumPy-compatible matrix library accelerated by CUDA";
    homepage = "https://cupy.dev/";
    # changelog = "https://github.com/cupy/cupy/releases/tag/v${version}";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = with lib.maintainers; [
      hyphon81
      connorbaker
    ];
  };
}
