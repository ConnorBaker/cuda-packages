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
    + ''
      pushd "$out/compat"
      mkdir -p "$out/lib"
      for file in *.so *.so.*
      do
        ln -s "$file" "$out/lib/$file"
      done
      popd
    ''
    + optionalString (cudaAtLeast "12") ''
      pushd "$out/compat"
      mkdir -p "$out/bin"
      for file in *
      do
        [[ -x "$file" ]] && ln -s "$file" "$out/bin/$file"
      done
      popd
    '';
}
