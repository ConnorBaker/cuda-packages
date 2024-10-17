{
  autoAddDriverRunpath,
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
  strictDeps = true;
  stdenv = backendStdenv;

  pname = "pycuda";
  version = "2024.1.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "inducer";
    repo = "pycuda";
    rev = "refs/tags/v2024.1.2";
    hash = "sha256-hOjb2TMSMxexNBermL6JHHc6CmHUSW6EKPbXyhp7B00=";
  };

  build-system = [
    setuptools
    wheel
  ];

  nativeBuildInputs = [
    autoAddDriverRunpath
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
    homepage = "https://github.com/inducer/pycuda/";
    description = "CUDA integration for Python";
    license = licenses.mit;
    maintainers = with maintainers; [ artuuge ];
  };
}