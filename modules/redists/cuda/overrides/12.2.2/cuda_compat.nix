{
  cudaAtLeast,
  flags,
  lib,
}:
let
  inherit (lib.lists) optionals;
  inherit (lib.strings) optionalString;
in
prevAttrs: {
  allowFHSReferences = true;

  autoPatchelfIgnoreMissingDeps =
    prevAttrs.autoPatchelfIgnoreMissingDeps or [ ]
    ++ optionals flags.isJetsonBuild [
      "libnvrm_gpu.so"
      "libnvrm_mem.so"
      "libnvdla_runtime.so"
    ];

  # `cuda_compat` only works on aarch64-linux, and only when building for Jetson devices.
  badPlatformsConditions = prevAttrs.badPlatformsConditions // {
    "Trying to use cuda_compat on aarch64-linux targeting non-Jetson devices" = !flags.isJetsonBuild;
  };

  # Set up symlinks for libraries and binaries.
  postInstall =
    prevAttrs.postInstall or ""
    # Create relative symlinks to shared object files in out/lib
    + ''
      mkdir -p "$out/lib"
      pushd "$out/compat"
      ln -srt "$out/lib/" *.so *.so.*
      popd
    ''
    # Create relative symlinks to executable files (not shared objects) in out/bin
    + optionalString (cudaAtLeast "12") ''
      mkdir -p "$out/bin"
      find \
        "$out/compat" \
        -mindepth 1 \
        -maxdepth 1 \
        -not -name "*.so" \
        -not -name "*.so.*" \
        -executable \
        -exec ln -srt "$out/bin/" '{}' '+'
    '';
}
