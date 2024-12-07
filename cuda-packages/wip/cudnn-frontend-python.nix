{
  addDriverRunpath,
  backendStdenv,
  cuda_cccl,
  cuda_cudart,
  cudnn,
  cudnn-frontend,
  cuda_nvcc,
  cudaAtLeast,
  fetchFromGitHub,
  flags,
  lib,
  python3,
  which,
  # passthru.updateScript
  gitUpdater,
}:
let
  inherit (lib.attrsets)
    getBin
    getLib
    getOutput
    ;
  inherit (lib.lists) optionals;
  inherit (lib.strings)
    cmakeBool
    optionalString
    cmakeFeature
    cmakeOptionType
    ;

  inherit (python3.pkgs)
    buildPythonPackage
    cmake # Yes, we need cmake from python3Packages in order for the build to work.
    pybind11
    ninja
    setuptools
    wheel
    ;

  dlpack = fetchFromGitHub {
    owner = "dmlc";
    repo = "dlpack";
    rev = "refs/tags/v0.8";
    hash = "sha256-IcfCoz3PfDdRetikc2MZM1sJFOyRgKonWMk21HPbrso=";
  };

  finalAttrs = {
    # Must opt-out of __structuredAttrs which is on by default in our stdenv, but currently incompatible with Python
    # packaging: https://github.com/NixOS/nixpkgs/pull/347194.
    __structuredAttrs = false;
    stdenv = backendStdenv;

    pname = "cudnn-frontend";
    version = "1.8.0";

    src = fetchFromGitHub {
      owner = "NVIDIA";
      repo = "cudnn-frontend";
      rev = "refs/tags/v${finalAttrs.version}";
      hash = "sha256-hKqIWGxVco1qkKxDZjc+pUisIcYJwFjZobJZg1WgDvY=";
    };

    # TODO: As a header-only library, we should make sure we have an `include` directory or similar which is not a
    # superset of the `out` (`bin`) or `dev` outputs (whih is what the multiple-outputs setup hook does by default).
    outputs = [
      "out"
    ];

    pyproject = true;

    build-system = [
      cmake
      ninja
      setuptools
      wheel
      pybind11
    ];

    nativeBuildInputs = [
      cuda_nvcc
      pybind11
    ];

    buildInputs = [
      cuda_cudart
      cudnn
      pybind11
    ];

    dependencies = [
      pybind11
    ];

    cmakeFlags = [
      (cmakeBool "CUDNN_FRONTEND_BUILD_SAMPLES" finalAttrs.doCheck)
      (cmakeBool "CUDNN_FRONTEND_BUILD_TESTS" finalAttrs.doCheck)
      (cmakeBool "CUDNN_FRONTEND_BUILD_PYTHON_BINDINGS" true) # TODO
      (cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
      (cmakeFeature "FETCHCONTENT_TRY_FIND_PACKAGE_MODE" "ALWAYS")
      (cmakeOptionType "PATH" "FETCHCONTENT_SOURCE_DIR_DLPACK" dlpack.outPath)
    ];

    preBuild =
      # Before the Python build starts, build the C++ components with CMake. Since the CMake setup hook has placed us in
      # cmakeBuildDir, we don't need to change the dir.
      ''
        echo "Running CMake build for C++ components"
        make all -j ''${NIX_BUILD_CORES:?}
      ''
      # Return to the root of the source tree, which contains the Python components.
      + ''
        cd "$NIX_BUILD_TOP/$sourceRoot"
      '';

    enableParallelBuilding = true;

    doCheck = false;

    # NOTE: Because the test cases immediately create and try to run the binaries, we don't have an opportunity
    # to patch them with autoAddDriverRunpath. To get around this, we add the driver runpath to the environment.
    preCheck = optionalString finalAttrs.doCheck ''
      export LD_LIBRARY_PATH="$(readlink -mnv "${addDriverRunpath.driverLink}/lib")"
    '';

    # This is *not* a derivation you want to build on a small machine.
    requiredSystemFeatures = optionals finalAttrs.doCheck [
      "big-parallel"
      "cuda"
    ];

    passthru = {
      updateScript = gitUpdater {
        inherit (finalAttrs) pname version;
        rev-prefix = "v";
      };
      tests.test = cudnn-frontend.overrideAttrs { doCheck = true; };
    };

    meta = with lib; {
      description = "Multi-GPU and multi-node collective communication primitives for NVIDIA GPUs";
      homepage = "https://developer.nvidia.com/nccl";
      license = licenses.mit;
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      maintainers = (with maintainers; [ connorbaker ]) ++ teams.cuda.members;
    };
  };
in

# TODO(@connorbaker): This should be a hybrid C++/Python package.
buildPythonPackage finalAttrs
