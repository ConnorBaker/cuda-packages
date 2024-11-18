{
  autoAddDriverRunpath,
  backendStdenv,
  catch2_3,
  cmake,
  cuda_cudart,
  cuda_nvcc,
  cuda_nvrtc,
  cudnn,
  fetchFromGitHub,
  gitUpdater,
  lib,
  libcublas,
  ninja,
}:
let
  inherit (lib.lists) optionals;
  inherit (lib.strings)
    cmakeBool
    cmakeFeature
    optionalString
    ;
in

# TODO(@connorbaker): This should be a hybrid C++/Python package.
backendStdenv.mkDerivation (finalAttrs: {
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
  outputs =
    [
      "out"
    ]
    ++ optionals finalAttrs.doCheck [
      "legacy_samples"
      "samples"
      "tests"
    ];

  nativeBuildInputs = [
    autoAddDriverRunpath # Needed for samples because it links against CUDA::cuda_driver
    cmake
    cuda_nvcc
    ninja
  ];

  buildInputs = [
    cuda_cudart
  ];

  # Link against forgotten libraries and add commands to install targets.
  postPatch = optionalString finalAttrs.doCheck ''
    echo >> ./CMakeLists.txt \
    "
    target_link_libraries(
      legacy_samples PRIVATE
      CUDA::cublasLt
      CUDA::nvrtc
    )

    target_link_libraries(
      samples PRIVATE
      CUDA::cublasLt
      CUDA::nvrtc
    )

    target_link_libraries(
      tests
      CUDA::cublasLt
      CUDA::nvrtc
    )

    install(
      TARGETS legacy_samples samples tests
      DESTINATION ''${CMAKE_INSTALL_BINDIR}
    )
    "
  '';

  cmakeFlags = [
    (cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
    (cmakeFeature "FETCHCONTENT_TRY_FIND_PACKAGE_MODE" "ALWAYS")
    (cmakeBool "CUDNN_FRONTEND_BUILD_SAMPLES" finalAttrs.doCheck)
    (cmakeBool "CUDNN_FRONTEND_BUILD_TESTS" finalAttrs.doCheck)
    (cmakeBool "CUDNN_FRONTEND_BUILD_PYTHON_BINDINGS" false)
  ];

  checkInputs = [
    cudnn
    cuda_nvrtc
    catch2_3
    libcublas
  ];

  enableParallelBuilding = true;

  enableParallelChecking = true;

  enableParallelInstalling = true;

  doCheck = true;

  # TODO: Assert bin is empty.
  postInstall = optionalString finalAttrs.doCheck ''
    moveToOutput "bin/legacy_samples" "$legacy_samples"
    moveToOutput "bin/samples" "$samples"
    moveToOutput "bin/tests" "$tests"
    if [[ -e "$out/bin" ]]
    then
      echo "The bin directory in \$out should no longer exist."
      exit 1
    fi
  '';

  passthru.updateScript = gitUpdater {
    inherit (finalAttrs) pname version;
    rev-prefix = "v";
  };

  meta = with lib; {
    description = "A c++ wrapper for the cudnn backend API";
    homepage = "https://github.com/NVIDIA/cudnn-frontend";
    license = licenses.mit;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = (with maintainers; [ connorbaker ]) ++ teams.cuda.members;
  };
})