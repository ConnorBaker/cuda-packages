{
  cudaPackagesConfig,
  lib,
  libcublas,
  mpi,
  nccl,
}:
prevAttrs: {
  buildInputs =
    prevAttrs.buildInputs or [ ]
    ++ [
      libcublas
    ]
    # MPI brings in NCCL dependency by way of UCC/UCX.
    ++ lib.optionals (!cudaPackagesConfig.hasJetsonCudaCapability) [
      mpi
      nccl
    ];

  # Update the CMake configurations
  postFixup =
    prevAttrs.postFixup or ""
    + ''
      pushd "''${!outputDev:?}/lib/cmake/cudss" >/dev/null

      nixLog "patching cudss-config.cmake to fix relative paths"
      substituteInPlace cudss-config.cmake \
        --replace-fail \
          'get_filename_component(PACKAGE_PREFIX_DIR "''${CMAKE_CURRENT_LIST_DIR}/../../../../" ABSOLUTE)' \
          "" \
        --replace-fail \
          'file(REAL_PATH "../../" _cudss_search_prefix BASE_DIRECTORY "''${_cudss_cmake_config_realpath}")' \
          'set(_cudss_search_prefix "${placeholder "dev"}/lib;${placeholder "lib"}/lib;${placeholder "include"}/include")'

      nixLog "patching cudss-static-targets-release.cmake to fix the path to the static library"
      substituteInPlace cudss-static-targets-release.cmake \
        --replace-fail \
          '"''${cudss_LIBRARY_DIR}/libcudss_static.a"' \
          '"${placeholder "static"}/lib/libcudss_static.a"'

      popd >/dev/null
    '';

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "dev"
        "include"
        "lib"
        "static"
      ];
    };
  };
}
