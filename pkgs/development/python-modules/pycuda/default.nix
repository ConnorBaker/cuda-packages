{
  _cuda,
  addDriverRunpath,
  boost,
  buildPythonPackage,
  cudaPackages,
  fetchFromGitHub,
  lib,
  mako,
  numpy,
  platformdirs,
  python,
  pytools,
  setuptools,
  wheel,
}:
let
  inherit (_cuda.lib) dropDots;
  inherit (cudaPackages)
    cuda_cudart
    cuda_nvcc
    cuda_profiler_api
    libcurand
    ;
  inherit (lib)
    getFirstOutput
    licenses
    maintainers
    teams
    ;
  inherit (lib.versions) majorMinor;

  compyteSrc = fetchFromGitHub {
    owner = "inducer";
    repo = "compyte";
    # Latest as of 2025-10-12
    rev = "2b168ca396aec2259da408f441f5e38ac9f95cb6";
    hash = "sha256-ibkHMWHSZrr2QVN4Un1Fg3c3VtYxm5O7NvOBs8JmAjg=";
  };
in
buildPythonPackage {
  __structuredAttrs = true;

  pname = "pycuda";
  version = "2025.1.2-unstable-2025-10-12";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "inducer";
    repo = "pycuda";
    rev = "34775b5bab8d06c6c724471980f702a0bcd8de31";
    hash = "sha256-Z9iYKzcL9mHv8ojo5S0M5PPEz4dqEKiySWhgjdq7zuY=";
  };

  build-system = [
    setuptools
    wheel
  ];

  nativeBuildInputs = [
    cuda_nvcc
  ];

  prePatch = ''
    nixLog "patching $PWD/setup.py to fix path to CUDA driver stub"
    substituteInPlace "$PWD/setup.py" \
      --replace-fail \
        '"''${CUDA_ROOT}/lib/stubs",' \
        '"${getFirstOutput [ "stubs" "lib" ] cuda_cudart}/lib/stubs",'
  '';

  preConfigure = ''
    ${python.pythonOnBuildForHost.interpreter} configure.py \
      --no-use-shipped-boost \
      --boost-python-libname=boost_python${dropDots (majorMinor python.version)}
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

  # Requires access to libcuda.so.1 which is provided by the driver
  doCheck = false;

  checkPhase = ''
    py.test
  '';

  postInstall = ''
    ln -s "${compyteSrc}" "$out/${python.sitePackages}/pycuda/compyte"
  '';

  # TODO(@connorbaker): Remove this when stubs in the runpath aren't an issue any more.
  # See: https://github.com/NixOS/nixpkgs/pull/459416.
  # NOTE: The string substitution assumes the path to be replaced is not the last path (it is followed by a :),
  # to avoid introducing an empty runpath entry (which would cause the current directory to be searched).
  postFixup = ''
    for file in "$out/${python.sitePackages}/pycuda/_driver."*.so; do
      nixLog "patching $file to replace link to stub in runpath"
      oldRpath=$(patchelf --print-rpath "$file")
      newRpath=$(
        substituteStream \
          oldRpath \
          "string runpath of '$file'" \
          --replace-fail \
          "${getFirstOutput [ "stubs" "lib" ] cuda_cudart}/lib/stubs:" \
          "${addDriverRunpath.driverLink}/lib:"
      )
      patchelf --set-rpath "$newRpath" "$file"
    done
    unset -v file oldRpath newRpath
  '';

  meta = {
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
