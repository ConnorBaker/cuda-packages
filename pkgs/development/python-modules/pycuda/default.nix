{
  boost,
  buildPythonPackage,
  config,
  cudaLib,
  cudaPackages,
  cudaSupport ? config.cudaSupport,
  fetchFromGitHub,
  lib,
  mako,
  numpy,
  platformdirs,
  python3,
  pytools,
  setuptools,
  wheel,
}:
let
  inherit (cudaLib.utils) dropDots;
  inherit (cudaPackages)
    cuda_cudart
    cuda_nvcc
    cuda_profiler_api
    libcurand
    ;
  inherit (lib) licenses maintainers teams;
  inherit (lib.versions) majorMinor;

  compyteSrc = fetchFromGitHub {
    owner = "inducer";
    repo = "compyte";
    rev = "955160ac2f504dabcd8641471a56146fa1afe35d";
    hash = "sha256-uObxDGBQ41HLDoKC5RtZk310niRjIupNiJaS2cFRP7c=";
  };
in
buildPythonPackage {
  # Must opt-out of __structuredAttrs which is set to true by default by cudaPackages.callPackage, but currently
  # incompatible with Python packaging: https://github.com/NixOS/nixpkgs/pull/347194.
  __structuredAttrs = false;

  pname = "pycuda";
  version = "2024.1.2-unstable-2024-11-05";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "inducer";
    repo = "pycuda";
    rev = "247be65a858ff0ee8a24ffc09013c067e028bbdf";
    hash = "sha256-i1Xy/WW8ZPL3EckExzFyBmO1D5BFX6jZMydmBDQZOA8=";
  };

  build-system = [
    setuptools
    wheel
  ];

  nativeBuildInputs = [
    cuda_nvcc
  ];

  preConfigure = ''
    ${python3.pythonOnBuildForHost.interpreter} configure.py \
      --no-use-shipped-boost \
      --boost-python-libname=boost_python${dropDots (majorMinor python3.version)}
  '';

  dependencies = [
    boost
    mako
    numpy
    platformdirs
    pytools
  ];

  buildInputs = [
    cuda_nvcc
    cuda_cudart
    cuda_profiler_api
    libcurand
  ];

  postInstall = ''
    ln -s "${compyteSrc}" "$out/${python3.sitePackages}/pycuda/compyte"
  '';

  # Requires access to libcuda.so.1 which is provided by the driver
  doCheck = false;

  checkPhase = ''
    py.test
  '';

  meta = {
    broken = !cudaSupport;
    description = "CUDA integration for Python";
    homepage = "https://github.com/inducer/pycuda/";
    license = licenses.mit;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers =
      (with maintainers; [
        artuuge
        connorbaker
      ])
      ++ teams.cuda.members;
  };
}
