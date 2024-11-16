{
  backendStdenv,
  cuda_cudart,
  cuda_nvcc,
  cuda_profiler_api,
  cuda-lib,
  fetchFromGitHub,
  lib,
  libcurand,
  python3,
}:
let
  inherit (python3.pkgs)
    boost
    buildPythonPackage
    mako
    numpy
    platformdirs
    pytools
    setuptools
    wheel
    ;

  compyteSrc = fetchFromGitHub {
    owner = "inducer";
    repo = "compyte";
    rev = "955160ac2f504dabcd8641471a56146fa1afe35d";
    hash = "sha256-uObxDGBQ41HLDoKC5RtZk310niRjIupNiJaS2cFRP7c=";
  };
  inherit (cuda-lib.utils) dropDots;
  inherit (lib.versions) majorMinor;
in
buildPythonPackage {
  # Must opt-out of __structuredAttrs which is on by default in our stdenv, but currently incompatible with Python
  # packaging: https://github.com/NixOS/nixpkgs/pull/347194.
  __structuredAttrs = false;
  stdenv = backendStdenv;

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
    ln -s ${compyteSrc} $out/${python3.sitePackages}/pycuda/compyte
  '';

  # Requires access to libcuda.so.1 which is provided by the driver
  doCheck = false;

  checkPhase = ''
    py.test
  '';

  meta = with lib; {
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
