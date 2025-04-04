{
  addDriverRunpath,
  arrayUtilities,
  cudaPackagesConfig,
  lib,
}:
prevAttrs: {
  allowFHSReferences = true;

  autoPatchelfIgnoreMissingDeps =
    prevAttrs.autoPatchelfIgnoreMissingDeps or [ ]
    ++ lib.optionals cudaPackagesConfig.hasJetsonCudaCapability [
      "libnvrm_gpu.so"
      "libnvrm_mem.so"
      "libnvdla_runtime.so"
    ];

  postInstall =
    prevAttrs.postInstall or ""
    + ''
      nixLog "creating symlinks for compat libs in ''${!outputLib:?}/lib"
      mkdir -p "''${!outputLib:?}/lib"
      ln -svt "''${!outputLib:?}/lib/" "''${out:?}/compat"/*.so "''${out:?}/compat"/*.so.*

      nixLog "creating symlinks for compat binaries in ''${!outputBin:?}/bin"
      mkdir -p "''${!outputBin:?}/bin"
      ln -svt "''${!outputBin:?}/bin/" "''${out:?}/compat"/nvidia-cuda-mps-*
    '';

  # Use postFixup because fixupPhase overwrites the dependency files in /nix-support.
  postFixup =
    prevAttrs.postFixup or ""
    # Install the setup hook in `out`, since the other outputs are symlinks to `out` (ensuring `out`'s setup hook is
    # always sourced).
    + ''
      mkdir -p "''${out:?}/nix-support"

      if [[ -f "''${out:?}/nix-support/setup-hook" ]]; then
        nixErrorLog "''${out:?}/nix-support/setup-hook already exists, unsure if this is correct!"
        exit 1
      fi

      nixLog "installing cudaCudartRunpathFixupHook.bash to ''${out:?}/nix-support/setup-hook"
      substitute \
        ${./cudaCompatRunpathFixupHook.bash} \
        "''${out:?}/nix-support/setup-hook" \
        --subst-var-by cudaCompatOutDir "''${out:?}/compat" \
        --subst-var-by cudaCompatLibDir "''${!outputLib:?}/lib" \
        --subst-var-by driverLibDir "${addDriverRunpath.driverLink}/lib"

      nixLog "installing cudaCudartRunpathFixupHook.bash dependencies to ''${out:?}/nix-support/propagated-host-host-deps"
      printWords \
        "${arrayUtilities.occursInArray}" \
        "${arrayUtilities.getRunpathEntries}" \
        >>"''${out:?}/nix-support/propagated-host-host-deps"
    '';

  passthru = prevAttrs.passthru or { } // {
    # `cuda_compat` only works on aarch64-linux, and only when building for Jetson devices.
    badPlatformsConditions = prevAttrs.passthru.badPlatformsConditions or { } // {
      "Trying to use cuda_compat on aarch64-linux targeting non-Jetson devices" =
        !cudaPackagesConfig.hasJetsonCudaCapability;
    };

    # NOTE: Using multiple outputs with symlinks causes build cycles.
    # To avoid that (and troubleshooting why), we just use a single output.
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [ "out" ];
    };
  };
}
