{
  lib,
  torch,
  buildPythonPackage,
  fetchFromGitHub,
  cmake,
  setuptools,
  scipy,
}:
let
  pname = "bitsandbytes";
  version = "0.45.5";

  inherit (torch) cudaPackages cudaSupport;
  inherit (cudaPackages)
    cuda_cudart
    cuda_nvcc
    cudaVersion
    flags
    libcublas
    libcusparse
    ;

  cudaVersionString = lib.replaceStrings [ "." ] [ "" ] (lib.versions.majorMinor cudaVersion);
in
buildPythonPackage {
  inherit pname version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "bitsandbytes-foundation";
    repo = "bitsandbytes";
    tag = version;
    hash = "sha256-YKrVT0cEAQS82uoG3XLqxVsMAjSUbfLK2OlrjN0bx8o=";
  };

  # By default, which library is loaded depends on the result of `torch.cuda.is_available()`.
  # When `cudaSupport` is enabled, bypass this check and load the cuda library unconditionally.
  # Indeed, in this case, only `libbitsandbytes_cuda124.so` is built. `libbitsandbytes_cpu.so` is not.
  # Also, hardcode the path to the previously built library instead of relying on
  # `get_cuda_bnb_library_path(cuda_specs)` which relies on `torch.cuda` too.
  #
  # WARNING: The cuda library is currently named `libbitsandbytes_cudaxxy` for cuda version `xx.y`.
  # This upstream convention could change at some point and thus break the following patch.
  postPatch = lib.optionalString cudaSupport ''
    substituteInPlace bitsandbytes/cextension.py \
      --replace-fail "if cuda_specs:" "if True:" \
      --replace-fail \
        "cuda_binary_path = get_cuda_bnb_library_path(cuda_specs)" \
        "cuda_binary_path = PACKAGE_DIR / 'libbitsandbytes_cuda${cudaVersionString}.so'"
  '';

  nativeBuildInputs = [
    cmake
  ]
  ++ lib.optionals cudaSupport [
    cuda_nvcc
  ];

  build-system = [
    setuptools
  ];

  buildInputs = lib.optionals cudaSupport [
    cuda_cudart
    libcublas
    libcusparse
  ];

  cmakeFlags = [
    (lib.cmakeFeature "COMPUTE_BACKEND" (if cudaSupport then "cuda" else "cpu"))
  ]
  ++ lib.optionals cudaSupport [
    (lib.cmakeFeature "COMPUTE_CAPABILITY" flags.cmakeCudaArchitecturesString)
  ];

  preBuild = ''
    make -j $NIX_BUILD_CORES
    cd .. # leave /build/source/build
  '';

  dependencies = [
    scipy
    torch
  ];

  doCheck = false; # tests require CUDA and also GPU access

  pythonImportsCheck = [ "bitsandbytes" ];

  meta = {
    description = "8-bit CUDA functions for PyTorch";
    homepage = "https://github.com/TimDettmers/bitsandbytes";
    changelog = "https://github.com/TimDettmers/bitsandbytes/releases/tag/${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ bcdarwin ];
  };
}
