{
  cudaConfig,
  lib,
  libcublas,
  mpi,
  nccl,
  stdenv,
}:
prevAttrs: {
  buildInputs =
    prevAttrs.buildInputs or [ ]
    ++ [
      libcublas
    ]
    # MPI brings in NCCL dependency by way of UCC/UCX.
    ++ lib.optionals (!cudaConfig.hasJetsonCudaCapability) [
      mpi
      nccl
    ];

  # Update the CMake configurations
  postFixup =
    let
      usrLocalCudaLib64Path = lib.concatStringsSep "/" (
        [
          "" # Leading slash
          "usr"
          "local"
          "cuda"
        ]
        ++ lib.optionals stdenv.isAarch64 [
          "targets"
          "aarch64-linux"
        ]
        ++ [
          "lib64"
        ]
      );
    in
    prevAttrs.postFixup or ""
    + ''
      pushd "''${!outputDev:?}/lib/cmake/cudss" >/dev/null

      nixLog "patching $PWD/cudss-config.cmake to fix relative paths"
      substituteInPlace "$PWD/cudss-config.cmake" \
        --replace-fail \
          'get_filename_component(PACKAGE_PREFIX_DIR "''${CMAKE_CURRENT_LIST_DIR}/../../../../" ABSOLUTE)' \
          "" \
        --replace-fail \
          'file(REAL_PATH "../../" _cudss_search_prefix BASE_DIRECTORY "''${_cudss_cmake_config_realpath}")' \
          "set(_cudss_search_prefix \"''${!outputDev:?}/lib;''${!outputLib:?}/lib;''${!outputInclude:?}/include\")"

      nixLog "patching $PWD/cudss-static-targets.cmake to fix INTERFACE_LINK_DIRECTORIES for cublas"
      substituteInPlace "$PWD/cudss-static-targets.cmake" \
        --replace-fail \
          'INTERFACE_LINK_DIRECTORIES "${usrLocalCudaLib64Path}"' \
          'INTERFACE_LINK_DIRECTORIES "${lib.getLib libcublas}/lib"'

      nixLog "patching $PWD/cudss-static-targets-release.cmake to fix the path to the static library"
      substituteInPlace "$PWD/cudss-static-targets-release.cmake" \
        --replace-fail \
          '"''${cudss_LIBRARY_DIR}/libcudss_static.a"' \
          "\"''${!outputStatic:?}/lib/libcudss_static.a\""

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
