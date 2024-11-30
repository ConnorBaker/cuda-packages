{
  cudaAtLeast,
  lib,
  mpi,
  nccl,
}:
let
  inherit (builtins) placeholder;
  inherit (lib.lists) optionals;
  inherit (lib.strings) optionalString;
in
prevAttrs: {
  buildInputs =
    prevAttrs.buildInputs or [ ]
    # TODO(@connorbaker): Are these required for 11.8?
    ++ optionals (cudaAtLeast "12.0") [
      mpi
      nccl
    ];

  # Update the CMake configurations
  postFixup =
    prevAttrs.postFixup or ""
    + optionalString (cudaAtLeast "12.0") (
      # Enter the directory containing the CMake configurations
      ''
        pushd "$dev/lib/cmake/cudss"
      ''
      # Patch cudss-config.cmake to fix the relative paths so they refer to our splayed outputs.
      + ''
        nixLog "patching cudss-config.cmake to fix relative paths"
        substituteInPlace cudss-config.cmake \
          --replace-fail \
           'get_filename_component(_cudss_search_prefix "''${CMAKE_CURRENT_LIST_DIR}/../../" ABSOLUTE)' \
           'set(_cudss_search_prefix "${placeholder "dev"}/lib;${placeholder "lib"}/lib;${placeholder "include"}/include")'
      ''
      # Patch cudss-targets-release.cmake to fix the path to the static library.
      + ''
        nixLog "patching cudss-targets-release.cmake to fix the path to the static library"
        substituteInPlace cudss-targets-release.cmake \
          --replace-fail \
          '"''${cudss_LIBRARY_DIR}/libcudss_static.a"' \
          '"${placeholder "static"}/lib/libcudss_static.a"'
      ''
      # Return to the original directory
      + ''
        popd
      ''
    );
}
