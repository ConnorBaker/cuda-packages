{
  lib,
  libcublas,
  mpi,
  nccl,
}:
let
  inherit (builtins) placeholder;
  inherit (lib.lists) elem optionals;
  inherit (lib.strings) optionalString versionAtLeast versionOlder;
in
finalAttrs: prevAttrs: {
  buildInputs =
    prevAttrs.buildInputs or [ ]
    ++ optionals (versionAtLeast finalAttrs.version "0.3") [
      mpi
      nccl
    ]
    ++ optionals (versionAtLeast finalAttrs.version "0.4") [
      libcublas
    ];

  # Update the CMake configurations
  postFixup =
    prevAttrs.postFixup or ""
    # Enter the directory containing the CMake configurations
    + ''
      pushd "$dev/lib/cmake/cudss"
    ''
    + optionalString (versionOlder finalAttrs.version "0.4") ''
      nixLog "patching cudss-config.cmake pre-0.4 release to fix relative paths"
      substituteInPlace cudss-config.cmake \
        --replace-fail \
         'get_filename_component(_cudss_search_prefix "''${CMAKE_CURRENT_LIST_DIR}/../../" ABSOLUTE)' \
         'set(_cudss_search_prefix "${placeholder "dev"}/lib;${placeholder "lib"}/lib;${placeholder "include"}/include")'
    ''
    + optionalString (versionAtLeast finalAttrs.version "0.4") ''
      nixLog "patching cudss-config.cmake post-0.4 release to fix relative paths"
      substituteInPlace cudss-config.cmake \
        --replace-fail \
         'get_filename_component(PACKAGE_PREFIX_DIR "''${CMAKE_CURRENT_LIST_DIR}/../../../../" ABSOLUTE)' \
         'set(_cudss_search_prefix "${placeholder "dev"}/lib;${placeholder "lib"}/lib;${placeholder "include"}/include")'
    ''
    # NOTE: Only the pre-0.4 release includes the line about the static library.
    + optionalString (versionOlder finalAttrs.version "0.4") ''
      nixLog "patching cudss-targets-release.cmake pre-0.4 release to fix the path to the static library"
      substituteInPlace cudss-targets-release.cmake \
        --replace-fail \
        '"''${cudss_LIBRARY_DIR}/libcudss_static.a"' \
        '"${placeholder "static"}/lib/libcudss_static.a"'
    ''
    # Return to the original directory
    + ''
      popd
    '';
}
